require_relative "../../test_helper"

class AnnesLoyalty::LoyaltyRedemptionTest < AnnesLoyalty::TestCase
  test "tracks issued token digest and status" do
    redemption = create_redemption

    assert redemption.issued?
    assert_equal "digest-1", redemption.token_digest
    assert_not redemption.token_expired?(at: redemption.issued_at + 1.minute)
    assert redemption.token_expired?(at: redemption.expires_at + 1.second)
  end

  test "rejects invalid status and expiry ordering" do
    issued_at = Time.current
    redemption = AnnesLoyalty::LoyaltyRedemption.new(
      loyalty_member: create_member,
      loyalty_reward: create_reward,
      status: "bad",
      token_digest: "digest-1",
      issued_at:,
      expires_at: issued_at
    )

    assert_not redemption.valid?
    assert_not_empty redemption.errors[:status]
    assert_not_empty redemption.errors[:expires_at]
  end

  test "requires unique token digest" do
    create_redemption(token_digest: "digest-1")
    duplicate = AnnesLoyalty::LoyaltyRedemption.new(
      loyalty_member: create_member,
      loyalty_reward: create_reward,
      status: "issued",
      token_digest: "digest-1",
      issued_at: Time.current,
      expires_at: 10.minutes.from_now
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:token_digest]
  end
end
