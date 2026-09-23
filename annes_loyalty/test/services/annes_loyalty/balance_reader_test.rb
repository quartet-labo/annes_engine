require_relative "../../test_helper"

class AnnesLoyalty::BalanceReaderTest < AnnesLoyalty::TestCase
  test "returns cached and lot balances with consistency flag" do
    member = create_member
    location = create_location(member.loyalty_program)
    AnnesLoyalty.earn!(member:, location:, amount_cents: 1_500, source: { type: "Receipt", key: "R-001" })

    balance = AnnesLoyalty.balance_for(member:)

    assert_equal 15, balance.cached_balance
    assert_equal 15, balance.lot_balance
    assert balance.consistent

    member.update_column(:cached_balance, 99)
    inconsistent = AnnesLoyalty.balance_for(member:)

    assert_equal 99, inconsistent.cached_balance
    assert_equal 15, inconsistent.lot_balance
    assert_not inconsistent.consistent
  end

  test "excludes expired open lots from spendable balance" do
    member = create_member
    member.loyalty_point_lots.create!(
      original_points: 20, remaining_points: 20, expires_on: Date.yesterday, status: "open"
    )
    member.loyalty_point_lots.create!(
      original_points: 10, remaining_points: 10, expires_on: Date.current, status: "open"
    )
    member.update!(cached_balance: 30)

    balance = AnnesLoyalty.balance_for(member:)

    assert_equal 30, balance.cached_balance
    assert_equal 10, balance.lot_balance
    assert_equal 10, balance.available_points
    assert_not balance.consistent
  end
end
