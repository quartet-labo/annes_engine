require "test_helper"

class AdminLoyaltyResourcesTest < ActionDispatch::IntegrationTest
  setup do
    @program = AnnesLoyalty::LoyaltyProgram.create!(
      code: "admin-demo",
      name: "Admin Demo",
      point_name: "pt",
      earn_unit_amount_cents: 100,
      earn_points_per_unit: 1,
      default_expiration_months: 12
    )
    @location = AnnesLoyalty::LoyaltyLocation.create!(
      loyalty_program: @program,
      code: "ginza",
      name: "Ginza",
      time_zone: "Asia/Tokyo"
    )
    @reward = AnnesLoyalty::LoyaltyReward.create!(
      loyalty_program: @program,
      code: "coffee",
      name: "コーヒー無料",
      required_points: 20,
      valid_minutes: 10
    )
  end

  test "loyalty admin resources are registered" do
    assert_includes AnnesAdmin.configuration.resources.map(&:name), "loyalty_programs"
    assert_includes AnnesAdmin.configuration.resources.map(&:name), "loyalty_locations"
    assert_includes AnnesAdmin.configuration.resources.map(&:name), "loyalty_rewards"

    rewards = AnnesAdmin.configuration.resources.fetch(:loyalty_rewards)
    assert_equal "特典", rewards.label
    assert_equal %i[loyalty_program_id code name required_points valid_minutes active created_at], rewards.fields.map(&:name)
    assert_equal %i[loyalty_program_id code name required_points valid_minutes active], rewards.permitted_attributes
  end

  test "admin manages loyalty rewards" do
    sign_in_as_role(:admin)

    get "/admin/loyalty_rewards", params: { q: "コーヒー" }
    assert_response :success
    assert_includes response.body, @reward.name

    assert_difference("AnnesLoyalty::LoyaltyReward.count") do
      post "/admin/loyalty_rewards", params: {
        loyalty_reward: {
          loyalty_program_id: @program.id,
          code: "cake",
          name: "ケーキ無料",
          required_points: 35,
          valid_minutes: 15,
          active: "1"
        }
      }
    end
  end

  test "staff and viewer cannot open loyalty reward write forms" do
    sign_in_as_role(:staff)
    get "/admin/loyalty_rewards/new"
    assert_response :forbidden

    delete admin_logout_path
    sign_in_as_role(:viewer)
    get "/admin/loyalty_rewards/new"
    assert_response :forbidden
  end
end
