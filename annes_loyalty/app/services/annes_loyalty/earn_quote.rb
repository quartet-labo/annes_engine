module AnnesLoyalty
  EarnQuoteResult = Data.define(:base_points, :bonus_points, :total_points, :breakdown)

  class EarnQuote
    def self.call(member:, location:, amount_cents:, occurred_at: Time.current, context: {})
      new(member:, location:, amount_cents:, occurred_at:, context:).call
    end

    def initialize(member:, location:, amount_cents:, occurred_at:, context:)
      @member = member
      @location = location
      @amount_cents = amount_cents.to_i
      @occurred_at = occurred_at
      @context = context || {}
    end

    def call
      EarnQuoteResult.new(
        base_points:,
        bonus_points: 0,
        total_points: base_points,
        breakdown: [{ "label" => "通常ポイント", "points" => base_points }]
      )
    end

    private
      attr_reader :member, :location, :amount_cents, :occurred_at, :context

      def base_points
        return 0 if amount_cents <= 0

        unit_count = amount_cents / member.loyalty_program.earn_unit_amount_cents
        unit_count * member.loyalty_program.earn_points_per_unit
      end
  end
end
