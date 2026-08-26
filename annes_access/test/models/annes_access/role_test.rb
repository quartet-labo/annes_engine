require_relative "../../test_helper"

class AnnesAccess::RoleTest < AnnesAccess::TestCase
  test "normalizes and validates key" do
    role = AnnesAccess::Role.create!(key: " Admin ", name: "Admin")

    assert_equal "admin", role.key
    duplicate = AnnesAccess::Role.new(key: "admin", name: "Duplicate")
    assert_not duplicate.valid?
  end

  test "rejects invalid key" do
    role = AnnesAccess::Role.new(key: "Admin User", name: "Admin")

    assert_not role.valid?
    assert_not_empty role.errors[:key]
  end
end
