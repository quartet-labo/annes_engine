require_relative "../../test_helper"

class AnneLoyalty::EarnQuoteTest < AnneLoyalty::TestCase
  test "calculates base points from the program earning settings" do
    member = create_member
    quote = AnneLoyalty.quote_earn(
      member:,
      location: create_location(member.loyalty_program),
      amount_cents: 3_250,
      occurred_at: Time.zone.parse("2026-07-26 12:00"),
      context: { "weather" => "rain" }
    )

    assert_equal 32, quote.base_points
    assert_equal 0, quote.bonus_points
    assert_equal 32, quote.total_points
    assert_equal [{ "label" => "通常ポイント", "points" => 32 }], quote.breakdown
  end
end
