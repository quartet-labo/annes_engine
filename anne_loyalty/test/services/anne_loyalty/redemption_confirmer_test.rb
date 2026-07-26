require_relative "../../test_helper"

class AnneLoyalty::RedemptionConfirmerTest < AnneLoyalty::TestCase
  test "confirms a token once and consumes points" do
    member = create_member
    location = create_location(member.loyalty_program)
    reward = create_reward(program: member.loyalty_program, required_points: 20)
    actor = Account.create!(email: "staff@example.com")
    AnneLoyalty.earn!(member:, location:, amount_cents: 3_000, source: { type: "Receipt", key: "R-001" })
    issue = AnneLoyalty.redeem_reward!(member:, reward:)

    redemption = AnneLoyalty.confirm_redemption!(
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
    assert_equal "127.0.0.1", redemption.metadata.fetch("ip")

    assert_raises(AnneLoyalty::AlreadyRedeemedError) do
      AnneLoyalty.confirm_redemption!(token: issue.token, location:, actor:)
    end
  end

  test "rejects invalid, expired, and mismatched location tokens" do
    member = create_member
    location = create_location(member.loyalty_program)
    other_location = create_location(create_program(code: "other-program"))
    reward = create_reward(program: member.loyalty_program, required_points: 10)
    AnneLoyalty.earn!(member:, location:, amount_cents: 1_000, source: { type: "Receipt", key: "R-001" })
    issue = AnneLoyalty.redeem_reward!(member:, reward:)

    assert_raises(AnneLoyalty::InvalidRedemptionTokenError) do
      AnneLoyalty.confirm_redemption!(token: "invalid", location:)
    end

    assert_raises(AnneLoyalty::InvalidRedemptionLocationError) do
      AnneLoyalty.confirm_redemption!(token: issue.token, location: other_location)
    end

    expired = create_redemption(
      member:,
      reward:,
      token_digest: AnneLoyalty::RedemptionToken.digest("expired-token"),
      issued_at: 20.minutes.ago
    )
    expired.update_columns(expires_at: 10.minutes.ago)

    assert_raises(AnneLoyalty::ExpiredRedemptionError) do
      AnneLoyalty.confirm_redemption!(token: "expired-token", location:)
    end
    assert expired.reload.expired?
  end
end
