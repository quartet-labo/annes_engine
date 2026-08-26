require_relative "../../test_helper"

class AnnesLoyalty::PointEarnerTest < AnnesLoyalty::TestCase
  test "adds an earn ledger entry, point lot, and cached balance in one command" do
    member = create_member
    location = create_location(member.loyalty_program)
    actor = Account.create!(email: "staff@example.com")

    entry = AnnesLoyalty.earn!(
      member:,
      location:,
      amount_cents: 2_000,
      source: { type: "Receipt", key: "R-001" },
      occurred_at: Time.zone.parse("2026-07-26 12:30"),
      actor:,
      metadata: { ip: "127.0.0.1", user_agent: "Rails test" }
    )

    member.reload
    lot = member.loyalty_point_lots.sole
    assert_equal "earn", entry.entry_type
    assert_equal 20, entry.points_delta
    assert_equal "Receipt", entry.source_type
    assert_equal "R-001", entry.source_key
    assert_equal 20, member.cached_balance
    assert_equal 20, member.lifetime_earned_points
    assert_equal 20, lot.original_points
    assert_equal 20, lot.remaining_points
    assert_equal Date.new(2027, 7, 26), lot.expires_on
    assert_equal "staff@example.com", entry.metadata.fetch("actor_label")
    assert_equal "127.0.0.1", entry.metadata.fetch("ip")
  end

  test "does not double add points for the same source" do
    member = create_member
    location = create_location(member.loyalty_program)

    first = AnnesLoyalty.earn!(member:, location:, amount_cents: 1_000, source: { type: "Receipt", key: "R-001" })
    second = AnnesLoyalty.earn!(member:, location:, amount_cents: 5_000, source: { type: "Receipt", key: "R-001" })

    assert_equal first, second
    assert_equal 10, member.reload.cached_balance
    assert_equal 1, member.loyalty_ledger_entries.count
    assert_equal 1, member.loyalty_point_lots.count
  end

  test "rejects earning at a location from another program" do
    member = create_member
    other_location = create_location(create_program(code: "other-earn-program"))

    assert_raises(AnnesLoyalty::InvalidEarningLocationError) do
      AnnesLoyalty.earn!(
        member:,
        location: other_location,
        amount_cents: 1_000,
        source: { type: "Receipt", key: "R-002" }
      )
    end

    assert_equal 0, member.reload.cached_balance
    assert_equal 0, member.loyalty_ledger_entries.count
    assert_equal 0, member.loyalty_point_lots.count
  end

  test "returns a zero earn result without creating ledger records" do
    member = create_member
    location = create_location(member.loyalty_program)

    result = AnnesLoyalty.earn!(
      member:,
      location:,
      amount_cents: 99,
      source: { type: "Receipt", key: "R-003" }
    )

    assert_instance_of AnnesLoyalty::ZeroEarnResult, result
    assert_equal 0, result.points_delta
    assert_equal "Receipt", result.source_type
    assert_equal "R-003", result.source_key
    assert_equal 0, member.reload.cached_balance
    assert_equal 0, member.loyalty_ledger_entries.count
    assert_equal 0, member.loyalty_point_lots.count
  end
end
