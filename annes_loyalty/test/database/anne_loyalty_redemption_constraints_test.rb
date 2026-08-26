require_relative "../test_helper"

class AnnesLoyaltyRedemptionConstraintsTest < AnnesLoyalty::TestCase
  test "database has reward and redemption constraints" do
    constraint_names = ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT conname
      FROM pg_constraint
      WHERE conrelid IN (
        'annes_loyalty_loyalty_rewards'::regclass,
        'annes_loyalty_loyalty_redemptions'::regclass
      )
    SQL

    index_names = ActiveRecord::Base.connection.indexes("annes_loyalty_loyalty_redemptions").map(&:name)

    assert_includes constraint_names, "annes_loyalty_rewards_positive_settings"
    assert_includes constraint_names, "annes_loyalty_redemptions_known_status"
    assert_includes constraint_names, "annes_loyalty_redemptions_expiry_after_issue"
    assert_includes index_names, "index_loyalty_redemptions_on_token_digest"
  end

  test "database rejects invalid redemption status" do
    member = create_member
    reward = create_reward(program: member.loyalty_program)

    assert_raises(ActiveRecord::StatementInvalid) do
      AnnesLoyalty::LoyaltyRedemption.insert!({
        loyalty_member_id: member.id,
        loyalty_reward_id: reward.id,
        status: "bad",
        token_digest: "digest-constraint",
        issued_at: Time.current,
        expires_at: 10.minutes.from_now,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "database rejects duplicate token digest" do
    create_redemption(token_digest: "digest-constraint")

    assert_raises(ActiveRecord::RecordNotUnique) do
      AnnesLoyalty::LoyaltyRedemption.insert!({
        loyalty_member_id: create_member.id,
        loyalty_reward_id: create_reward.id,
        status: "issued",
        token_digest: "digest-constraint",
        issued_at: Time.current,
        expires_at: 10.minutes.from_now,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end
end
