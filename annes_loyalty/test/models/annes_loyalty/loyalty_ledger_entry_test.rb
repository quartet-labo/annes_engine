require_relative "../../test_helper"

class AnnesLoyalty::LoyaltyLedgerEntryTest < AnnesLoyalty::TestCase
  test "records known entry types and idempotency keys" do
    member = create_member
    location = create_location(member.loyalty_program)
    entry = AnnesLoyalty::LoyaltyLedgerEntry.create!(
      loyalty_member: member,
      loyalty_location: location,
      entry_type: "earn",
      points_delta: 10,
      source_type: "Receipt",
      source_key: "R-001",
      occurred_at: Time.current,
      metadata: { "actor" => "staff@example.com" }
    )

    assert entry.earn?
    assert_equal 10, entry.points_delta
    assert_equal({ "actor" => "staff@example.com" }, entry.metadata)

    duplicate = AnnesLoyalty::LoyaltyLedgerEntry.new(
      loyalty_member: member,
      loyalty_location: location,
      entry_type: "earn",
      points_delta: 10,
      source_type: "Receipt",
      source_key: "R-001",
      occurred_at: Time.current
    )

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:source_key]
  end

  test "rejects unknown entry types" do
    entry = AnnesLoyalty::LoyaltyLedgerEntry.new(
      loyalty_member: create_member,
      entry_type: "bonus",
      points_delta: 1,
      occurred_at: Time.current
    )

    assert_not entry.valid?
    assert_not_empty entry.errors[:entry_type]
  end
end
