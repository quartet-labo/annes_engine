require_relative "../../test_helper"

class AnneLoyalty::LoyaltyMemberTest < AnneLoyalty::TestCase
  test "connects a host owner through a polymorphic association" do
    program = create_program
    owner = Account.create!(email: "owner@example.com")
    member = AnneLoyalty::LoyaltyMember.create!(
      loyalty_program: program,
      owner: owner,
      member_key: " CARD-001 "
    )

    assert_equal owner, member.owner
    assert_equal "CARD-001", member.member_key
    assert_equal 0, member.cached_balance
    assert_equal 0, member.lifetime_earned_points
  end

  test "requires unique owner and member key within a program" do
    program = create_program
    owner = Account.create!(email: "owner@example.com")
    AnneLoyalty::LoyaltyMember.create!(loyalty_program: program, owner:, member_key: "CARD-001")

    duplicate_owner = AnneLoyalty::LoyaltyMember.new(loyalty_program: program, owner:, member_key: "CARD-002")
    duplicate_key = AnneLoyalty::LoyaltyMember.new(
      loyalty_program: program,
      owner: Account.create!(email: "other@example.com"),
      member_key: "CARD-001"
    )

    assert_not duplicate_owner.valid?
    assert_not_empty duplicate_owner.errors[:owner_id]
    assert_not duplicate_key.valid?
    assert_not_empty duplicate_key.errors[:member_key]
  end
end
