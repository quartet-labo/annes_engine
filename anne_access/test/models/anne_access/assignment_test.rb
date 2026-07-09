require_relative "../../test_helper"

class AnneAccess::AssignmentTest < AnneAccess::TestCase
  test "assigns a role to a polymorphic principal once" do
    account = Account.create!(email: "admin@example.com")
    role = AnneAccess::Role.create!(key: "admin", name: "Admin")
    AnneAccess::Assignment.create!(principal: account, role:)

    duplicate = AnneAccess::Assignment.new(principal: account, role:)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:role_id]
  end
end
