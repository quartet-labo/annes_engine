require_relative "../../test_helper"

class AnneLoyalty::BalanceReaderTest < AnneLoyalty::TestCase
  test "returns cached and lot balances with consistency flag" do
    member = create_member
    location = create_location(member.loyalty_program)
    AnneLoyalty.earn!(member:, location:, amount_cents: 1_500, source: { type: "Receipt", key: "R-001" })

    balance = AnneLoyalty.balance_for(member:)

    assert_equal 15, balance.cached_balance
    assert_equal 15, balance.lot_balance
    assert balance.consistent

    member.update_column(:cached_balance, 99)
    inconsistent = AnneLoyalty.balance_for(member:)

    assert_equal 99, inconsistent.cached_balance
    assert_equal 15, inconsistent.lot_balance
    assert_not inconsistent.consistent
  end
end
