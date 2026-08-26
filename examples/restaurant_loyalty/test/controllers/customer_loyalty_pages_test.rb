require "test_helper"

class CustomerLoyaltyPagesTest < ActionDispatch::IntegrationTest
  setup do
    @customer = Customer.create!(name: "山田 太郎", email: "taro@example.com", access_code: "123456")
    @other_customer = Customer.create!(name: "佐藤 花子", email: "hanako@example.com", access_code: "654321")
    @program = AnnesLoyalty::LoyaltyProgram.create!(
      code: "restaurant-demo",
      name: "Restaurant Demo",
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
    @member = AnnesLoyalty.enroll!(program: @program, owner: @customer, member_key: @customer.customer_number)
    AnnesLoyalty.enroll!(program: @program, owner: @other_customer, member_key: @other_customer.customer_number)
    @coffee = AnnesLoyalty::LoyaltyReward.create!(
      loyalty_program: @program,
      code: "coffee",
      name: "コーヒー無料",
      required_points: 20,
      valid_minutes: 10
    )
    @dessert = AnnesLoyalty::LoyaltyReward.create!(
      loyalty_program: @program,
      code: "dessert",
      name: "デザート無料",
      required_points: 40,
      valid_minutes: 10
    )
    AnnesLoyalty.earn!(
      member: @member,
      location: @location,
      amount_cents: 2_500,
      source: { type: "Receipt", key: "R-001" },
      occurred_at: Time.zone.parse("2026-07-26 12:00")
    )
  end

  test "customer pages require customer authentication" do
    get customer_root_path(customer_id: @customer.id)

    assert_redirected_to customer_login_path
  end

  test "customer can sign in and sign out" do
    get customer_login_path
    assert_response :success
    assert_includes response.body, "顧客ログイン"

    post customer_session_path, params: { customer_number: @customer.customer_number, access_code: "wrong" }
    assert_response :unprocessable_content

    sign_in_customer(@customer)
    follow_redirect!
    assert_response :success
    assert_includes response.body, "山田 太郎"

    delete customer_logout_path
    assert_redirected_to customer_login_path
  end

  test "customer_id query does not switch the authenticated customer" do
    sign_in_customer(@customer)

    get customer_root_path(customer_id: @other_customer.id)

    assert_response :success
    assert_includes response.body, "山田 太郎"
    assert_not_includes response.body, "佐藤 花子"
    assert_not_includes response.body, "customer_id="
  end

  test "customer dashboard shows balance and next reward progress" do
    sign_in_customer(@customer)
    get customer_root_path

    assert_response :success
    assert_includes response.body, "山田 太郎"
    assert_includes response.body, "25 pt"
    assert_includes response.body, "デザート無料"
  end

  test "customer card shows member QR payload" do
    sign_in_customer(@customer)
    get customer_card_path

    assert_response :success
    assert_includes response.body, @member.member_key
    assert_includes response.body, "member:#{@member.member_key}"
  end

  test "rewards page distinguishes available and unavailable rewards" do
    sign_in_customer(@customer)
    get customer_rewards_path

    assert_response :success
    assert_includes response.body, "コーヒー無料"
    assert_includes response.body, "交換"
    assert_includes response.body, "あと 15 pt"
  end

  test "customer can issue a redemption token" do
    sign_in_customer(@customer)
    post customer_reward_redemption_path(@coffee)

    assert_response :created
    assert_includes response.body, "特典QR"
    assert_includes response.body, "redemption:"
    assert_equal 1, @member.loyalty_redemptions.count
  end

  test "history shows loyalty ledger entries" do
    sign_in_customer(@customer)
    get customer_history_path

    assert_response :success
    assert_includes response.body, "付与"
    assert_includes response.body, "25 pt"
    assert_includes response.body, "Ginza"
  end
end
