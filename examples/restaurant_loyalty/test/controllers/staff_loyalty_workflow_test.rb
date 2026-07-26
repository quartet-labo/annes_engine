require "test_helper"

class StaffLoyaltyWorkflowTest < ActionDispatch::IntegrationTest
  setup do
    @customer = Customer.create!(name: "山田 太郎")
    @program = AnneLoyalty::LoyaltyProgram.create!(
      code: "staff-workflow",
      name: "Staff Workflow",
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
    @reward = AnneLoyalty::LoyaltyReward.create!(
      loyalty_program: @program,
      code: "coffee",
      name: "コーヒー無料",
      required_points: 20,
      valid_minutes: 10
    )
  end

  test "staff can search members and earn points idempotently" do
    sign_in_as_role(:staff)

    get staff_members_path(q: @member.member_key)
    assert_response :success
    assert_includes response.body, @member.member_key

    post staff_earn_points_path,
      params: { member_key: @member.member_key, amount_cents: 2_500, receipt_number: "R-ST-001" }
    assert_response :created
    assert_includes response.body, "25 pt"
    assert_equal 25, @member.reload.cached_balance

    post staff_earn_points_path,
      params: { member_key: @member.member_key, amount_cents: 9_900, receipt_number: "R-ST-001" }
    assert_response :created
    assert_equal 25, @member.reload.cached_balance
    assert_equal 1, @member.loyalty_ledger_entries.where(source_type: "Receipt", source_key: "R-ST-001").count
  end

  test "staff cannot reuse another customer's receipt number" do
    sign_in_as_role(:staff)
    other_customer = Customer.create!(name: "佐藤 花子")
    other_member = AnneLoyalty.enroll!(
      program: @program,
      owner: other_customer,
      member_key: other_customer.customer_number
    )
    Receipt.create!(
      customer: @customer,
      loyalty_location: @location,
      amount_cents: 2_500,
      receipt_number: "R-ST-REUSED",
      purchased_at: Time.current
    )

    post staff_earn_points_path,
      params: { member_key: other_member.member_key, amount_cents: 2_500, receipt_number: "R-ST-REUSED" }

    assert_response :unprocessable_content
    assert_includes response.body, "already been used"
    assert_equal 0, other_member.reload.cached_balance
    assert_equal 0, other_member.loyalty_ledger_entries.count
  end

  test "staff can confirm redemption tokens once" do
    sign_in_as_role(:staff)
    AnneLoyalty.earn!(member: @member, location: @location, amount_cents: 3_000, source: { type: "Receipt", key: "R-ST-002" })
    issue = AnneLoyalty.redeem_reward!(member: @member, reward: @reward)

    post staff_redemptions_path, params: { token: issue.token }

    assert_response :created
    assert_includes response.body, "特典利用完了"
    assert_equal 10, @member.reload.cached_balance

    post staff_redemptions_path, params: { token: issue.token }
    assert_response :unprocessable_content
    assert_includes response.body, "already"
  end

  test "viewer cannot earn or redeem points" do
    sign_in_as_role(:viewer)

    post staff_earn_points_path,
      params: { member_key: @member.member_key, amount_cents: 2_500, receipt_number: "R-ST-003" }
    assert_response :forbidden

    post staff_redemptions_path, params: { token: "invalid" }
    assert_response :forbidden
  end
end
