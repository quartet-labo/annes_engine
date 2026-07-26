require_relative "../../test_helper"

class AnneLoyalty::LoyaltyProgramTest < AnneLoyalty::TestCase
  test "normalizes and validates code" do
    program = AnneLoyalty::LoyaltyProgram.create!(
      code: " Cafe Main ",
      name: "Cafe Main",
      point_name: "pt",
      earn_unit_amount_cents: 100,
      earn_points_per_unit: 1,
      default_expiration_months: 12
    )

    assert_equal "cafe-main", program.code
    duplicate = AnneLoyalty::LoyaltyProgram.new(
      code: "cafe-main",
      name: "Duplicate",
      point_name: "pt",
      earn_unit_amount_cents: 100,
      earn_points_per_unit: 1,
      default_expiration_months: 12
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:code]
  end

  test "requires positive earning settings" do
    program = AnneLoyalty::LoyaltyProgram.new(
      code: "invalid",
      name: "Invalid",
      point_name: "pt",
      earn_unit_amount_cents: 0,
      earn_points_per_unit: 0,
      default_expiration_months: 0
    )

    assert_not program.valid?
    assert_not_empty program.errors[:earn_unit_amount_cents]
    assert_not_empty program.errors[:earn_points_per_unit]
    assert_not_empty program.errors[:default_expiration_months]
  end
end
