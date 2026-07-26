require_relative "../../test_helper"

class AnneLoyalty::PointLotConsumerTest < AnneLoyalty::TestCase
  test "consumes open lots by earliest expiration date" do
    member = create_member
    later = AnneLoyalty::LoyaltyPointLot.create!(
      loyalty_member: member,
      original_points: 20,
      remaining_points: 20,
      expires_on: Date.current + 2.months,
      status: "open"
    )
    earlier = AnneLoyalty::LoyaltyPointLot.create!(
      loyalty_member: member,
      original_points: 10,
      remaining_points: 10,
      expires_on: Date.current + 1.month,
      status: "open"
    )

    AnneLoyalty::PointLotConsumer.call(member:, points: 12)

    assert_equal 0, earlier.reload.remaining_points
    assert_equal "consumed", earlier.status
    assert_equal 18, later.reload.remaining_points
    assert_equal "open", later.status
  end

  test "rejects consumption beyond available points" do
    member = create_member

    assert_raises(AnneLoyalty::InsufficientPointsError) do
      AnneLoyalty::PointLotConsumer.call(member:, points: 1)
    end
  end
end
