module AnnesLoyalty
  class LedgerReverser
    def self.call(ledger_entry:, reason:, actor: nil, metadata: {})
      new(ledger_entry:, reason:, actor:, metadata:).call
    end

    def initialize(ledger_entry:, reason:, actor:, metadata:)
      @ledger_entry = ledger_entry
      @reason = reason
      @actor = actor
      @metadata = metadata
    end

    def call
      LoyaltyMember.transaction do
        member.lock!
        ledger_entry.lock!
        raise AlreadyReversedError, "ledger entry has already been reversed" if already_reversed?

        apply_balance_change!
        create_reverse_entry!
      end
    end

    private
      attr_reader :ledger_entry, :reason, :actor, :metadata

      def member
        @member ||= ledger_entry.loyalty_member
      end

      def already_reversed?
        member.loyalty_ledger_entries.exists?(
          entry_type: "reverse",
          source_type: ledger_entry.class.name,
          source_key: ledger_entry.id.to_s
        )
      end

      def apply_balance_change!
        delta = -ledger_entry.points_delta
        if delta.negative?
          PointLotConsumer.call(member:, points: delta.abs)
        else
          restore_consumed_lots!(delta) || create_fallback_lot!(delta)
        end

        member.cached_balance += delta
        member.save!
      end

      def create_reverse_entry!
        member.loyalty_ledger_entries.create!(
          loyalty_location: ledger_entry.loyalty_location,
          entry_type: "reverse",
          points_delta: -ledger_entry.points_delta,
          source_type: ledger_entry.class.name,
          source_key: ledger_entry.id.to_s,
          occurred_at: Time.current,
          metadata: AuditMetadata.build(
            actor:,
            metadata: metadata.merge(
              "reason" => reason,
              "reversed_ledger_entry_id" => ledger_entry.id.to_s,
              "restored_lots" => restored_lots
            )
          )
        )
      end

      def restore_consumed_lots!(points)
        consumed_lots = Array(ledger_metadata["consumed_lots"] || ledger_metadata[:consumed_lots])
        return false if consumed_lots.empty?

        restored_points = 0
        consumed_lots.each do |consumed_lot|
          lot_points = (consumed_lot["points"] || consumed_lot[:points]).to_i
          next if lot_points <= 0

          lot_id = consumed_lot["loyalty_point_lot_id"] || consumed_lot[:loyalty_point_lot_id]
          expires_on = Date.iso8601((consumed_lot["expires_on"] || consumed_lot[:expires_on]).to_s)
          member.loyalty_point_lots.create!(
            original_points: lot_points,
            remaining_points: lot_points,
            expires_on:,
            status: "open"
          )
          restored_lots << {
            "loyalty_point_lot_id" => lot_id.to_s,
            "points" => lot_points,
            "expires_on" => expires_on.iso8601
          }
          restored_points += lot_points
        end

        return true if restored_points == points

        raise Error, "consumed lot metadata does not match reversal points"
      end

      def create_fallback_lot!(points)
        member.loyalty_point_lots.create!(
          original_points: points,
          remaining_points: points,
          expires_on: Date.current.advance(months: member.loyalty_program.default_expiration_months),
          status: "open"
        )
        true
      end

      def restored_lots
        @restored_lots ||= []
      end

      def ledger_metadata
        @ledger_metadata ||= ledger_entry.metadata || {}
      end
  end
end
