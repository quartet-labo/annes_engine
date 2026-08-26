require_relative "../../test_helper"

class AnnesAccess::RolePermissionTest < AnnesAccess::TestCase
  test "requires unique permission per role" do
    role = AnnesAccess::Role.create!(key: "admin", name: "Admin")
    permission = AnnesAccess::Permission.create!(resource: "customers", action: "read")
    AnnesAccess::RolePermission.create!(role:, permission:)

    duplicate = AnnesAccess::RolePermission.new(role:, permission:)

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:permission_id]
  end
end
