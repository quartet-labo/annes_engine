module AnnesLoyalty
  Balance = Data.define(:cached_balance, :lot_balance, :consistent) do
    def available_points
      [cached_balance, lot_balance].min
    end
  end

  class BalanceReader
    def self.call(member:)
      new(member:).call
    end

    def initialize(member:)
      @member = member
    end

    def call
      member.reload
      lot_balance = member.loyalty_point_lots.spendable.sum(:remaining_points)

      Balance.new(
        cached_balance: member.cached_balance,
        lot_balance:,
        consistent: member.cached_balance == lot_balance
      )
    end

    private
      attr_reader :member
  end
end
