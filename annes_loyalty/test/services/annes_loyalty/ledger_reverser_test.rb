require_relative "../../test_helper"

class AnnesLoyalty::LedgerReverserTest < AnnesLoyalty::TestCase
  test "reverses an earn entry without mutating the original ledger entry" do
    member = create_member
    location = create_location(member.loyalty_program)
    actor = Account.create!(email: "manager@example.com")
    earn_entry = AnnesLoyalty.earn!(member:, location:, amount_cents: 3_000, source: { type: "Receipt", key: "R-001" })

    reverse_entry = AnnesLoyalty.reverse!(ledger_entry: earn_entry, reason: "receipt voided", actor:)

    assert_equal "earn", earn_entry.reload.entry_type
    assert_equal "reverse", reverse_entry.entry_type
    assert_equal(-30, reverse_entry.points_delta)
    assert_equal 0, member.reload.cached_balance
    assert_equal 0, member.loyalty_point_lots.sum(:remaining_points)
    assert_equal earn_entry.id.to_s, reverse_entry.metadata.fetch("reversed_ledger_entry_id")
    assert_equal "receipt voided", reverse_entry.metadata.fetch("reason")

    assert_raises(AnnesLoyalty::AlreadyReversedError) do
      AnnesLoyalty.reverse!(ledger_entry: earn_entry, reason: "duplicate", actor:)
    end
  end

  test "reversing a debit restores points with consumed lot expirations" do
    member = create_member
    location = create_location(member.loyalty_program)
    reward = create_reward(program: member.loyalty_program, required_points: 25)
    earlier = AnnesLoyalty::LoyaltyPointLot.create!(
      loyalty_member: member,
      original_points: 10,
      remaining_points: 10,
      expires_on: Date.current + 1.month,
      status: "open"
    )
    later = AnnesLoyalty::LoyaltyPointLot.create!(
      loyalty_member: member,
      original_points: 20,
      remaining_points: 20,
      expires_on: Date.current + 2.months,
      status: "open"
    )
    member.update!(cached_balance: 30, lifetime_earned_points: 30)
    create_redemption(
      member:,
      reward:,
      token_digest: AnnesLoyalty::RedemptionToken.digest("restore-token"),
      issued_at: Time.current
    )

    AnnesLoyalty.confirm_redemption!(
      token: "restore-token",
      location:,
      occurred_at: Time.current
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

    reverse_entry = AnnesLoyalty.reverse!(ledger_entry: debit_entry, reason: "reward voided")

    assert_equal 30, member.reload.cached_balance
    assert_equal 10, member.loyalty_point_lots.open.where(expires_on: earlier.expires_on).sum(:remaining_points)
    assert_equal 20, member.loyalty_point_lots.open.where(expires_on: later.expires_on).sum(:remaining_points)
    assert_equal debit_entry.metadata.fetch("consumed_lots"), reverse_entry.metadata.fetch("restored_lots")
  end

  test "reversing a new earn consumes spendable points before expired lots" do
    member = create_member
    location = create_location(member.loyalty_program)
    expired = member.loyalty_point_lots.create!(
      original_points: 20, remaining_points: 20, expires_on: Date.yesterday, status: "open"
    )
    member.update!(cached_balance: 20, lifetime_earned_points: 20)
    earn_entry = AnnesLoyalty.earn!(
      member:, location:, amount_cents: 1_000, source: { type: "Receipt", key: "new-earn" }
    )
    new_lot = member.loyalty_point_lots.order(:id).last

    AnnesLoyalty.reverse!(ledger_entry: earn_entry, reason: "void")

    assert_equal 20, member.reload.cached_balance
    assert_equal 20, expired.reload.remaining_points
    assert_equal 0, new_lot.reload.remaining_points
    assert_equal 0, AnnesLoyalty.balance_for(member:).available_points
  end

  test "reversing an expired historical earn preserves newer spendable points" do
    member = create_member
    location = create_location(member.loyalty_program)
    old_entry = AnnesLoyalty.earn!(
      member:, location:, amount_cents: 1_000,
      source: { type: "Receipt", key: "expired-earn" }, occurred_at: 14.months.ago
    )
    expired_lot = member.loyalty_point_lots.order(:id).last
    AnnesLoyalty.earn!(
      member:, location:, amount_cents: 1_000, source: { type: "Receipt", key: "valid-earn" }
    )
    valid_lot = member.loyalty_point_lots.order(:id).last
    old_entry.update!(metadata: old_entry.metadata.except("earned_lot"))
    assert_operator expired_lot.expires_on, :<, Date.current
    assert_equal 10, AnnesLoyalty.balance_for(member:).available_points

    AnnesLoyalty.reverse!(ledger_entry: old_entry, reason: "old receipt voided")

    assert_equal 0, expired_lot.reload.remaining_points
    assert_equal 10, valid_lot.reload.remaining_points
    assert_equal 10, member.reload.cached_balance
    assert_equal 10, AnnesLoyalty.balance_for(member:).available_points
  end

  test "reversing a new earn consumes its recorded lot before another valid lot" do
    member = create_member
    location = create_location(member.loyalty_program)
    AnnesLoyalty.earn!(
      member:, location:, amount_cents: 1_000, source: { type: "Receipt", key: "earlier-valid" }
    )
    earlier_lot = member.loyalty_point_lots.order(:id).last
    new_entry = AnnesLoyalty.earn!(
      member:, location:, amount_cents: 1_000, source: { type: "Receipt", key: "later-valid" }
    )
    new_lot = member.loyalty_point_lots.order(:id).last

    AnnesLoyalty.reverse!(ledger_entry: new_entry, reason: "new receipt voided")

    assert_equal 10, earlier_lot.reload.remaining_points
    assert_equal 0, new_lot.reload.remaining_points
    assert_equal 10, AnnesLoyalty.balance_for(member:).available_points
  end
end
