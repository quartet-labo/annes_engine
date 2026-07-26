require_relative "../../test_helper"

class AnneLoyalty::EnrollmentTest < AnneLoyalty::TestCase
  test "enrolls an owner and returns the existing member idempotently" do
    program = create_program
    owner = Account.create!(email: "enroll@example.com")

    member = AnneLoyalty.enroll!(program:, owner:, member_key: "CARD-001")
    duplicate = AnneLoyalty.enroll!(program:, owner:, member_key: "CARD-001")

    assert_equal member, duplicate
    assert_equal 1, AnneLoyalty::LoyaltyMember.where(loyalty_program: program, owner:).count
  end
end
