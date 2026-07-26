module AnneLoyalty
  Balance = Data.define(:cached_balance, :lot_balance, :consistent)

  class BalanceReader
    def self.call(member:)
      new(member:).call
    end

    def initialize(member:)
      @member = member
    end

    def call
      member.reload
      lot_balance = member.loyalty_point_lots.open.sum(:remaining_points)

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
