require_relative "../../test_helper"

class AnnesLoyalty::PointLotConsumerTest < AnnesLoyalty::TestCase
  test "consumes open lots by earliest expiration date" do
    member = create_member
    later = AnnesLoyalty::LoyaltyPointLot.create!(
      loyalty_member: member,
      original_points: 20,
      remaining_points: 20,
      expires_on: Date.current + 2.months,
      status: "open"
    )
    earlier = AnnesLoyalty::LoyaltyPointLot.create!(
      loyalty_member: member,
      original_points: 10,
      remaining_points: 10,
      expires_on: Date.current + 1.month,
      status: "open"
    )

    consumed_lots = AnnesLoyalty::PointLotConsumer.call(member:, points: 12)

    assert_equal 0, earlier.reload.remaining_points
    assert_equal "consumed", earlier.status
    assert_equal 18, later.reload.remaining_points
    assert_equal "open", later.status
    assert_equal [
      {
        "loyalty_point_lot_id" => earlier.id.to_s,
        "points" => 10,
        "expires_on" => earlier.expires_on.iso8601
      },
      {
        "loyalty_point_lot_id" => later.id.to_s,
        "points" => 2,
        "expires_on" => later.expires_on.iso8601
      }
    ], consumed_lots
  end

  test "rejects consumption beyond available points" do
    member = create_member

    assert_raises(AnnesLoyalty::InsufficientPointsError) do
      AnnesLoyalty::PointLotConsumer.call(member:, points: 1)
    end
  end
end
