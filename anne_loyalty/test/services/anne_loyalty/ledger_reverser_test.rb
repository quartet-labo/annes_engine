require_relative "../../test_helper"

class AnneLoyalty::LedgerReverserTest < AnneLoyalty::TestCase
  test "reverses an earn entry without mutating the original ledger entry" do
    member = create_member
    location = create_location(member.loyalty_program)
    actor = Account.create!(email: "manager@example.com")
    earn_entry = AnneLoyalty.earn!(member:, location:, amount_cents: 3_000, source: { type: "Receipt", key: "R-001" })

    reverse_entry = AnneLoyalty.reverse!(ledger_entry: earn_entry, reason: "receipt voided", actor:)

    assert_equal "earn", earn_entry.reload.entry_type
    assert_equal "reverse", reverse_entry.entry_type
    assert_equal(-30, reverse_entry.points_delta)
    assert_equal 0, member.reload.cached_balance
    assert_equal 0, member.loyalty_point_lots.sum(:remaining_points)
    assert_equal earn_entry.id.to_s, reverse_entry.metadata.fetch("reversed_ledger_entry_id")
    assert_equal "receipt voided", reverse_entry.metadata.fetch("reason")

    assert_raises(AnneLoyalty::AlreadyReversedError) do
      AnneLoyalty.reverse!(ledger_entry: earn_entry, reason: "duplicate", actor:)
    end
  end

  test "reversing a debit restores points with consumed lot expirations" do
    member = create_member
    location = create_location(member.loyalty_program)
    reward = create_reward(program: member.loyalty_program, required_points: 25)
    earlier = AnneLoyalty::LoyaltyPointLot.create!(
      loyalty_member: member,
      original_points: 10,
      remaining_points: 10,
      expires_on: Date.new(2026, 8, 1),
      status: "open"
    )
    later = AnneLoyalty::LoyaltyPointLot.create!(
      loyalty_member: member,
      original_points: 20,
      remaining_points: 20,
      expires_on: Date.new(2026, 9, 1),
      status: "open"
    )
    member.update!(cached_balance: 30, lifetime_earned_points: 30)
    create_redemption(
      member:,
      reward:,
      token_digest: AnneLoyalty::RedemptionToken.digest("restore-token"),
      issued_at: Time.zone.parse("2026-07-26 12:00")
    )

    AnneLoyalty.confirm_redemption!(
      token: "restore-token",
      location:,
      occurred_at: Time.zone.parse("2026-07-26 12:01")
    )
    debit_entry = member.loyalty_ledger_entries.where(entry_type: "redeem").sole

    assert_equal [
      {
        "loyalty_point_lot_id" => earlier.id.to_s,
        "points" => 10,
        "expires_on" => earlier.expires_on.iso8601
      },
      {
        "loyalty_point_lot_id" => later.id.to_s,
        "points" => 15,
        "expires_on" => later.expires_on.iso8601
      }
    ], debit_entry.metadata.fetch("consumed_lots")

    reverse_entry = AnneLoyalty.reverse!(ledger_entry: debit_entry, reason: "reward voided")

    assert_equal 30, member.reload.cached_balance
    assert_equal 10, member.loyalty_point_lots.open.where(expires_on: earlier.expires_on).sum(:remaining_points)
    assert_equal 20, member.loyalty_point_lots.open.where(expires_on: later.expires_on).sum(:remaining_points)
    assert_equal debit_entry.metadata.fetch("consumed_lots"), reverse_entry.metadata.fetch("restored_lots")
  end
end
