require "test_helper"

class DemoWorkflowTest < ActionDispatch::IntegrationTest
  test "seeded demo supports customer redemption and staff confirmation" do
    Rails.application.load_seed

    customer = Customer.find_by!(customer_number: "C-DEMO-001")
    member = customer.loyalty_member
    coffee = AnnesLoyalty::LoyaltyReward.find_by!(code: "coffee")

    sign_in_seeded_customer(customer.customer_number)
    get customer_root_path(customer_id: Customer.find_by!(customer_number: "C-DEMO-002").id)
    assert_response :success
    assert_includes response.body, customer.name
    assert_not_includes response.body, "佐藤 花子"
    assert_includes response.body, "25 pt"

    sign_in_as_role(:staff)
    post "/staff/earn",
      params: {
        member_key: member.member_key,
        receipt_number: "R-DEMO-ACCEPTANCE",
        amount_cents: 1_500
      }

    assert_response :created
    assert_equal 40, member.reload.cached_balance

    post customer_reward_redemption_path(coffee)
    assert_response :created
    token = response.body.match(/redemption:([A-Za-z0-9._-]+)/)[1]
    assert_equal 1, member.loyalty_redemptions.where(loyalty_reward: coffee).count

    post staff_redemptions_path, params: { token: }
    assert_response :created
    assert_includes response.body, "特典利用完了"
    assert_equal 20, member.reload.cached_balance

    post staff_redemptions_path, params: { token: }
    assert_response :unprocessable_content
    assert_includes response.body, "already"
    assert_equal 20, member.reload.cached_balance
  end

  test "seeded admin and viewer roles keep write operations separated" do
    Rails.application.load_seed

    sign_in_seeded_account("admin@example.com")
    get "/admin/loyalty_rewards/new"
    assert_response :success

    post "/admin/loyalty_rewards",
      params: {
        loyalty_reward: {
          loyalty_program_id: AnnesLoyalty::LoyaltyProgram.find_by!(code: "cafe-demo").id,
          code: "tea",
          name: "紅茶無料",
          required_points: 25,
          valid_minutes: 10,
          active: "1"
        }
      }
    assert_response :redirect
    assert AnnesLoyalty::LoyaltyReward.exists?(code: "tea")

    delete "/admin/logout"
    sign_in_seeded_account("viewer@example.com")

    post "/staff/earn",
      params: {
        member_key: Customer.find_by!(customer_number: "C-DEMO-001").loyalty_member.member_key,
        receipt_number: "R-DEMO-FORBIDDEN",
        amount_cents: 1_000
      }
    assert_response :forbidden

    get "/admin/loyalty_rewards/new"
    assert_response :forbidden
  end

  private
    def sign_in_seeded_account(email)
      post "/admin/session",
        params: { email:, password: "password-1234" },
        headers: { "REMOTE_ADDR" => "192.0.2.55" }
      assert_redirected_to admin_root_path
    end

    def sign_in_seeded_customer(customer_number)
      post "/customer/session",
        params: { customer_number:, access_code: "123456" },
        headers: { "REMOTE_ADDR" => "198.51.100.55" }
      assert_redirected_to customer_root_path
    end
end
