require_relative "../../test_helper"

class AnnesLoyalty::LoyaltyLocationTest < AnnesLoyalty::TestCase
  test "normalizes code within a program" do
    program = create_program
    location = AnnesLoyalty::LoyaltyLocation.create!(
      loyalty_program: program,
      code: " Ginza ",
      name: "Ginza",
      time_zone: "Asia/Tokyo"
    )

    assert_equal "ginza", location.code
    duplicate = AnnesLoyalty::LoyaltyLocation.new(
      loyalty_program: program,
      code: "ginza",
      name: "Duplicate",
      time_zone: "Asia/Tokyo"
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:code]
  end

  test "requires a known time zone" do
    location = AnnesLoyalty::LoyaltyLocation.new(
      loyalty_program: create_program,
      code: "bad-zone",
      name: "Bad Zone",
      time_zone: "Mars/Base"
    )

    assert_not location.valid?
    assert_not_empty location.errors[:time_zone]
  end
end
