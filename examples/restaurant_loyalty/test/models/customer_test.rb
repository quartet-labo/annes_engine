require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "assigns a customer number and can own a loyalty member" do
    customer = Customer.create!(name: "山田 太郎", email: "taro@example.com")
    program = AnnesLoyalty::LoyaltyProgram.create!(
      code: "demo",
      name: "Demo",
      point_name: "pt",
      earn_unit_amount_cents: 100,
      earn_points_per_unit: 1,
      default_expiration_months: 12
    )

    member = AnnesLoyalty.enroll!(program:, owner: customer, member_key: customer.customer_number)

    assert_match(/\AC-[0-9A-F]{8}\z/, customer.customer_number)
    assert_equal customer, member.owner
    assert_equal member, customer.loyalty_member
  end
end
