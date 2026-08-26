require_relative "../../test_helper"

class AnnesAccess::AssignmentTest < AnnesAccess::TestCase
  test "assigns a role to a polymorphic principal once" do
    account = Account.create!(email: "admin@example.com")
    role = AnnesAccess::Role.create!(key: "admin", name: "Admin")
    AnnesAccess::Assignment.create!(principal: account, role:)

    duplicate = AnnesAccess::Assignment.new(principal: account, role:)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:role_id]
  end
end
