module AnnesLoyalty
  ZeroEarnResult = Data.define(:points_delta, :source_type, :source_key, :metadata) do
    def entry_type
      "earn"
    end

    def persisted?
      false
    end
  end

  class PointEarner
    def self.call(member:, location:, amount_cents:, source:, occurred_at: Time.current, actor: nil, metadata: {})
      new(member:, location:, amount_cents:, source:, occurred_at:, actor:, metadata:).call
    end

    def initialize(member:, location:, amount_cents:, source:, occurred_at:, actor:, metadata:)
      @member = member
      @location = location
      @amount_cents = amount_cents
      @source = SourceReference.resolve(source)
      @occurred_at = occurred_at
      @actor = actor
      @metadata = metadata
    end

    def call
      LoyaltyMember.transaction do
        member.lock!
        validate_location!

        existing_entry = existing_idempotent_entry
        return existing_entry if existing_entry

        quote = EarnQuote.call(member:, location:, amount_cents:, occurred_at:, context: {})
        return zero_earn_result(quote) if quote.total_points.zero?

        entry = create_ledger_entry!(quote)
        create_point_lot!(quote.total_points)
        update_member_balance!(quote.total_points)
        entry
      end
    end

    private
      attr_reader :member, :location, :amount_cents, :source, :occurred_at, :actor, :metadata

      def existing_idempotent_entry
        member.loyalty_ledger_entries.find_by(source_type: source.type, source_key: source.key)
      end

      def validate_location!
        return if location.loyalty_program_id == member.loyalty_program_id

        raise InvalidEarningLocationError, "location does not belong to the member program"
      end

      def zero_earn_result(quote)
        ZeroEarnResult.new(
          points_delta: 0,
          source_type: source.type,
          source_key: source.key,
          metadata: AuditMetadata.build(actor:, metadata: metadata.merge("quote" => quote.to_h))
        )
      end

      def create_ledger_entry!(quote)
        member.loyalty_ledger_entries.create!(
          loyalty_location: location,
          entry_type: "earn",
          points_delta: quote.total_points,
          source_type: source.type,
          source_key: source.key,
          occurred_at: occurred_at || Time.current,
          metadata: AuditMetadata.build(actor:, metadata: metadata.merge("quote" => quote.to_h))
        )
      end

      def create_point_lot!(points)
        member.loyalty_point_lots.create!(
          original_points: points,
          remaining_points: points,
          expires_on: expiration_date,
          status: "open"
        )
      end

      def update_member_balance!(points)
        member.cached_balance += points
        member.lifetime_earned_points += points
        member.save!
      end

      def expiration_date
        reference_time = occurred_at || Time.current
        zone = ActiveSupport::TimeZone[location.time_zone] || Time.zone
        reference_time.in_time_zone(zone).to_date.advance(months: member.loyalty_program.default_expiration_months)
      end
  end
end
