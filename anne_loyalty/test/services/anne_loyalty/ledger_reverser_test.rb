require_relative "../../test_helper"

class AnneLoyalty::LedgerReverserTest < AnneLoyalty::TestCase
  test "reverses an earn entry without mutating the original ledger entry" do
    member = create_member
    location = create_location(member.loyalty_program)
    actor = Account.create!(email: "manager@example.com")
    earn_entry = AnneLoyalty.earn!(member:, location:, amount_cents: 3_000, source: { type: "Receipt", key: "R-001" })

    reverse_entry = AnneLoyalty.reverse!(ledger_entry: earn_entry, reason: "receipt voided", actor:)

    assert_equal "earn", earn_entry.reload.entry_type
    assert_equal "reverse", reverse_entry.entry_type
    assert_equal(-30, reverse_entry.points_delta)
    assert_equal 0, member.reload.cached_balance
    assert_equal 0, member.loyalty_point_lots.sum(:remaining_points)
    assert_equal earn_entry.id.to_s, reverse_entry.metadata.fetch("reversed_ledger_entry_id")
    assert_equal "receipt voided", reverse_entry.metadata.fetch("reason")

    assert_raises(AnneLoyalty::AlreadyReversedError) do
      AnneLoyalty.reverse!(ledger_entry: earn_entry, reason: "duplicate", actor:)
    end
  end
end
