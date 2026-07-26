require_relative "../../test_helper"

class AnneLoyalty::LoyaltyPointLotTest < AnneLoyalty::TestCase
  test "tracks remaining points and expiration" do
    lot = AnneLoyalty::LoyaltyPointLot.create!(
      loyalty_member: create_member,
      original_points: 30,
      remaining_points: 20,
      expires_on: Date.current + 1.year,
      status: "open"
    )

    assert lot.open?
    assert_equal 20, lot.remaining_points
  end

  test "rejects invalid remaining points and status" do
    lot = AnneLoyalty::LoyaltyPointLot.new(
      loyalty_member: create_member,
      original_points: 10,
      remaining_points: 11,
      expires_on: Date.current,
      status: "unknown"
    )

    assert_not lot.valid?
    assert_not_empty lot.errors[:remaining_points]
    assert_not_empty lot.errors[:status]
  end
end
