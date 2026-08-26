require_relative "../../test_helper"

class AnnesLoyalty::LoyaltyRewardTest < AnnesLoyalty::TestCase
  test "normalizes code within a program" do
    program = create_program
    reward = AnnesLoyalty::LoyaltyReward.create!(
      loyalty_program: program,
      code: " Free Coffee ",
      name: "Free Coffee",
      required_points: 50,
      valid_minutes: 10
    )

    assert_equal "free-coffee", reward.code
    duplicate = AnnesLoyalty::LoyaltyReward.new(
      loyalty_program: program,
      code: "free-coffee",
      name: "Duplicate",
      required_points: 50,
      valid_minutes: 10
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:code]
  end

  test "requires positive points and validity window" do
    reward = AnnesLoyalty::LoyaltyReward.new(
      loyalty_program: create_program,
      code: "invalid",
      name: "Invalid",
      required_points: 0,
      valid_minutes: 0
    )

    assert_not reward.valid?
    assert_not_empty reward.errors[:required_points]
    assert_not_empty reward.errors[:valid_minutes]
  end
end
