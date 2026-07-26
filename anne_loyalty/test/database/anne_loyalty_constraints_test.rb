require_relative "../test_helper"

class AnneLoyaltyConstraintsTest < AnneLoyalty::TestCase
  test "database has core check constraints and idempotency index" do
    constraint_names = ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT conname
      FROM pg_constraint
      WHERE conrelid IN (
        'anne_loyalty_loyalty_programs'::regclass,
        'anne_loyalty_loyalty_ledger_entries'::regclass,
        'anne_loyalty_loyalty_point_lots'::regclass
      )
    SQL

    index_names = ActiveRecord::Base.connection.indexes("anne_loyalty_loyalty_ledger_entries").map(&:name)

    assert_includes constraint_names, "anne_loyalty_programs_positive_earn_settings"
    assert_includes constraint_names, "anne_loyalty_ledger_entries_known_type"
    assert_includes constraint_names, "anne_loyalty_point_lots_remaining_range"
    assert_includes index_names, "index_loyalty_ledger_entries_on_idempotency_key"
  end

  test "database rejects duplicate member owner within a program" do
    member = create_member
    owner_id = member.owner_id

    assert_raises(ActiveRecord::RecordNotUnique) do
      AnneLoyalty::LoyaltyMember.insert!({
        loyalty_program_id: member.loyalty_program_id,
        owner_type: "Account",
        owner_id:,
        member_key: "OTHER",
        cached_balance: 0,
        lifetime_earned_points: 0,
        active: true,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "database rejects duplicate member key within a program" do
    member = create_member

    assert_raises(ActiveRecord::RecordNotUnique) do
      AnneLoyalty::LoyaltyMember.insert!({
        loyalty_program_id: member.loyalty_program_id,
        owner_type: "Account",
        owner_id: Account.create!(email: "other-constraint@example.com").id,
        member_key: member.member_key,
        cached_balance: 0,
        lifetime_earned_points: 0,
        active: true,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end

  test "database rejects invalid lot ranges and entry types" do
    member = create_member

    assert_raises(ActiveRecord::StatementInvalid) do
      AnneLoyalty::LoyaltyPointLot.insert!({
        loyalty_member_id: member.id,
        original_points: 10,
        remaining_points: 11,
        expires_on: Date.current,
        status: "open",
        created_at: Time.current,
        updated_at: Time.current
      })
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      AnneLoyalty::LoyaltyLedgerEntry.insert!({
        loyalty_member_id: member.id,
        entry_type: "bad",
        points_delta: 1,
        occurred_at: Time.current,
        metadata: {},
        created_at: Time.current,
        updated_at: Time.current
      })
    end
  end
end
