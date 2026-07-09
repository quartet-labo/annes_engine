require_relative "../../test_helper"

class AnneAccess::RolePermissionTest < AnneAccess::TestCase
  test "requires unique permission per role" do
    role = AnneAccess::Role.create!(key: "admin", name: "Admin")
    permission = AnneAccess::Permission.create!(resource: "customers", action: "read")
    AnneAccess::RolePermission.create!(role:, permission:)

    duplicate = AnneAccess::RolePermission.new(role:, permission:)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:permission_id]
  end
end
