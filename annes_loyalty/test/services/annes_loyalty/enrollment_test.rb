require_relative "../../test_helper"

class AnnesLoyalty::EnrollmentTest < AnnesLoyalty::TestCase
  test "enrolls an owner and returns the existing member idempotently" do
    program = create_program
    owner = Account.create!(email: "enroll@example.com")

    member = AnnesLoyalty.enroll!(program:, owner:, member_key: "CARD-001")
    duplicate = AnnesLoyalty.enroll!(program:, owner:, member_key: "CARD-001")

    assert_equal member, duplicate
    assert_equal 1, AnnesLoyalty::LoyaltyMember.where(loyalty_program: program, owner:).count
  end

  test "returns the existing member when concurrent creation wins the unique race" do
    program = create_program
    owner = Account.create!(email: "race@example.com")
    existing = AnnesLoyalty::LoyaltyMember.new(loyalty_program: program, owner:, member_key: "CARD-001")
    find_calls = 0
    finder = ->(**) do
      find_calls += 1
      find_calls == 1 ? nil : existing
    end
    creator = ->(**) { raise ActiveRecord::RecordNotUnique.new("duplicate member") }

    original_find_by = AnnesLoyalty::LoyaltyMember.method(:find_by)
    original_create = AnnesLoyalty::LoyaltyMember.method(:create!)
    silence_warnings do
      AnnesLoyalty::LoyaltyMember.define_singleton_method(:find_by, finder)
      AnnesLoyalty::LoyaltyMember.define_singleton_method(:create!, creator)
    end

    assert_same existing, AnnesLoyalty.enroll!(program:, owner:, member_key: "CARD-001")
    assert_equal 2, find_calls
  ensure
    silence_warnings do
      AnnesLoyalty::LoyaltyMember.define_singleton_method(:find_by, original_find_by) if original_find_by
      AnnesLoyalty::LoyaltyMember.define_singleton_method(:create!, original_create) if original_create
    end
  end
end
