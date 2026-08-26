require_relative "../../test_helper"

class AnnesAccess::PermissionTest < AnnesAccess::TestCase
  test "assigns key from resource and action" do
    permission = AnnesAccess::Permission.create!(resource: " Customers ", action: " READ ")

    assert_equal "customers", permission.resource
    assert_equal "read", permission.action
    assert_equal "customers.read", permission.key
  end

  test "requires unique resource action pair" do
    AnnesAccess::Permission.create!(resource: "customers", action: "read")
    duplicate = AnnesAccess::Permission.new(resource: "customers", action: "read")

    assert_not duplicate.valid?
    assert_not_empty duplicate.errors[:action]
  end
end
