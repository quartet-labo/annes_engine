require_relative "../../test_helper"

class AnneLoyalty::RewardRedemptionIssuerTest < AnneLoyalty::TestCase
  test "issues a redemption token without storing the raw token" do
    member = create_member
    location = create_location(member.loyalty_program)
    reward = create_reward(program: member.loyalty_program, required_points: 20)
    AnneLoyalty.earn!(member:, location:, amount_cents: 2_000, source: { type: "Receipt", key: "R-001" })

    issue = AnneLoyalty.redeem_reward!(member:, reward:, actor: Account.create!(email: "customer@example.com"))
    redemption = issue.redemption

    assert_not_empty issue.token
    assert_equal "issued", redemption.status
    assert_equal 20, member.reload.cached_balance
    assert_equal 0, member.loyalty_ledger_entries.where(entry_type: "redeem").count
    assert_not_equal issue.token, redemption.token_digest
    assert_equal AnneLoyalty::RedemptionToken.digest(issue.token), redemption.token_digest
    assert_equal reward.valid_minutes.minutes.from_now.to_i, redemption.expires_at.to_i
  end

  test "rejects inactive rewards and insufficient balances" do
    member = create_member
    reward = create_reward(program: member.loyalty_program, required_points: 20)

    assert_raises(AnneLoyalty::InsufficientPointsError) do
      AnneLoyalty.redeem_reward!(member:, reward:)
    end

    reward.update!(active: false)
    member.update!(cached_balance: 20)

    assert_raises(AnneLoyalty::InactiveRewardError) do
      AnneLoyalty.redeem_reward!(member:, reward:)
    end
  end
end
