require "test_helper"

class CustomerLoyaltyPagesTest < ActionDispatch::IntegrationTest
  setup do
    @customer = Customer.create!(name: "山田 太郎", email: "taro@example.com")
    @program = AnneLoyalty::LoyaltyProgram.create!(
      code: "restaurant-demo",
      name: "Restaurant Demo",
      point_name: "pt",
      earn_unit_amount_cents: 100,
      earn_points_per_unit: 1,
      default_expiration_months: 12
    )
    @location = AnneLoyalty::LoyaltyLocation.create!(
      loyalty_program: @program,
      code: "ginza",
      name: "Ginza",
      time_zone: "Asia/Tokyo"
    )
    @member = AnneLoyalty.enroll!(program: @program, owner: @customer, member_key: @customer.customer_number)
    @coffee = AnneLoyalty::LoyaltyReward.create!(
      loyalty_program: @program,
      code: "coffee",
      name: "コーヒー無料",
      required_points: 20,
      valid_minutes: 10
    )
    @dessert = AnneLoyalty::LoyaltyReward.create!(
      loyalty_program: @program,
      code: "dessert",
      name: "デザート無料",
      required_points: 40,
      valid_minutes: 10
    )
    AnneLoyalty.earn!(
      member: @member,
      location: @location,
      amount_cents: 2_500,
      source: { type: "Receipt", key: "R-001" },
      occurred_at: Time.zone.parse("2026-07-26 12:00")
    )
  end

  test "customer dashboard shows balance and next reward progress" do
    get customer_root_path(customer_id: @customer.id)

    assert_response :success
    assert_includes response.body, "山田 太郎"
    assert_includes response.body, "25 pt"
    assert_includes response.body, "デザート無料"
  end

  test "customer card shows member QR payload" do
    get customer_card_path(customer_id: @customer.id)

    assert_response :success
    assert_includes response.body, @member.member_key
    assert_includes response.body, "member:#{@member.member_key}"
  end

  test "rewards page distinguishes available and unavailable rewards" do
    get customer_rewards_path(customer_id: @customer.id)

    assert_response :success
    assert_includes response.body, "コーヒー無料"
    assert_includes response.body, "交換"
    assert_includes response.body, "あと 15 pt"
  end

  test "customer can issue a redemption token" do
    post customer_reward_redemption_path(@coffee, customer_id: @customer.id)

    assert_response :created
    assert_includes response.body, "特典QR"
    assert_includes response.body, "redemption:"
    assert_equal 1, @member.loyalty_redemptions.count
  end

  test "history shows loyalty ledger entries" do
    get customer_history_path(customer_id: @customer.id)

    assert_response :success
    assert_includes response.body, "付与"
    assert_includes response.body, "25 pt"
    assert_includes response.body, "Ginza"
  end
end
