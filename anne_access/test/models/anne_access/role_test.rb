require_relative "../../test_helper"

class AnneAccess::RoleTest < AnneAccess::TestCase
  test "normalizes and validates key" do
    role = AnneAccess::Role.create!(key: " Admin ", name: "Admin")

    assert_equal "admin", role.key
    duplicate = AnneAccess::Role.new(key: "admin", name: "Duplicate")
    assert_not duplicate.valid?
  end

  test "rejects invalid key" do
    role = AnneAccess::Role.new(key: "Admin User", name: "Admin")

    assert_not role.valid?
    assert_not_empty role.errors[:key]
  end
end
