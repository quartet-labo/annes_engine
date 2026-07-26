module AnneLoyalty
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
          member.loyalty_point_lots.create!(
            original_points: delta,
            remaining_points: delta,
            expires_on: Date.current.advance(months: member.loyalty_program.default_expiration_months),
            status: "open"
          )
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
              "reversed_ledger_entry_id" => ledger_entry.id.to_s
            )
          )
        )
      end
  end
end
