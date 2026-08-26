require_relative "../../test_helper"

class AnnesLoyalty::RedemptionConfirmerTest < AnnesLoyalty::TestCase
  test "confirms a token once and consumes points" do
    member = create_member
    location = create_location(member.loyalty_program)
    reward = create_reward(program: member.loyalty_program, required_points: 20)
    actor = Account.create!(email: "staff@example.com")
    AnnesLoyalty.earn!(member:, location:, amount_cents: 3_000, source: { type: "Receipt", key: "R-001" })
    issue = AnnesLoyalty.redeem_reward!(member:, reward:)

    redemption = AnnesLoyalty.confirm_redemption!(
      token: issue.token,
      location:,
      actor:,
      metadata: { ip: "127.0.0.1" }
    )

    member.reload
    ledger = member.loyalty_ledger_entries.where(entry_type: "redeem").sole
    assert redemption.redeemed?
    assert_equal location, redemption.redeemed_loyalty_location
    assert_equal 10, member.cached_balance
    assert_equal(-20, ledger.points_delta)
    assert_equal redemption.id.to_s, ledger.source_key
    assert_equal "staff@example.com", ledger.metadata.fetch("actor_label")
    assert_equal 20, ledger.metadata.fetch("consumed_lots").sole.fetch("points")
    assert_equal "127.0.0.1", redemption.metadata.fetch("ip")

    assert_raises(AnnesLoyalty::AlreadyRedeemedError) do
      AnnesLoyalty.confirm_redemption!(token: issue.token, location:, actor:)
    end
  end

  test "reports already redeemed before expiry for used tokens" do
    issued_at = Time.zone.parse("2026-07-26 12:00")
    member = create_member
    location = create_location(member.loyalty_program)
    reward = create_reward(program: member.loyalty_program, required_points: 20)
    AnnesLoyalty.earn!(member:, location:, amount_cents: 3_000, source: { type: "Receipt", key: "R-001" })
    issue = AnnesLoyalty.redeem_reward!(member:, reward:, issued_at:)

    AnnesLoyalty.confirm_redemption!(token: issue.token, location:, occurred_at: issued_at + 1.minute)

    assert_raises(AnnesLoyalty::AlreadyRedeemedError) do
      AnnesLoyalty.confirm_redemption!(token: issue.token, location:, occurred_at: issued_at + 20.minutes)
    end
    assert issue.redemption.reload.redeemed?
  end

  test "rejects invalid, expired, and mismatched location tokens" do
    member = create_member
    location = create_location(member.loyalty_program)
    other_location = create_location(create_program(code: "other-program"))
    reward = create_reward(program: member.loyalty_program, required_points: 10)
    AnnesLoyalty.earn!(member:, location:, amount_cents: 1_000, source: { type: "Receipt", key: "R-001" })
    issue = AnnesLoyalty.redeem_reward!(member:, reward:)

    assert_raises(AnnesLoyalty::InvalidRedemptionTokenError) do
      AnnesLoyalty.confirm_redemption!(token: "invalid", location:)
    end

    assert_raises(AnnesLoyalty::InvalidRedemptionLocationError) do
      AnnesLoyalty.confirm_redemption!(token: issue.token, location: other_location)
    end

    expired = create_redemption(
      member:,
      reward:,
      token_digest: AnnesLoyalty::RedemptionToken.digest("expired-token"),
      issued_at: 20.minutes.ago
    )
    expired.update_columns(expires_at: 10.minutes.ago)

    assert_raises(AnnesLoyalty::ExpiredRedemptionError) do
      AnnesLoyalty.confirm_redemption!(token: "expired-token", location:)
    end
    assert expired.reload.expired?
  end
end
