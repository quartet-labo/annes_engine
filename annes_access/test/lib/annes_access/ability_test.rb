require_relative "../../test_helper"

class AnnesAccess::AbilityTest < AnnesAccess::TestCase
  test "allows action through assigned role permission" do
    account = account_with_permission(resource: "customers", action: "read")

    assert AnnesAccess.can?(account, :read, :customers)
  end

  test "denies action without permission" do
    account = account_with_permission(resource: "customers", action: "read")

    assert_not AnnesAccess.can?(account, :update, :customers)
  end

  test "manage allows standard actions for same resource" do
    account = account_with_permission(resource: "projects", action: "manage")

    assert AnnesAccess.can?(account, :read, :projects)
    assert AnnesAccess.can?(account, :update, :projects)
    assert_not AnnesAccess.can?(account, :read, :customers)
    assert_not AnnesAccess.can?(account, :approve, :projects)
  end

  test "denies nil principal and unknown resource" do
    account = account_with_permission(resource: "customers", action: "read")

    assert_not AnnesAccess.can?(nil, :read, :customers)
    assert_not AnnesAccess.can?(account, :read, :unknown)
  end

  test "authorize raises when denied" do
    account = account_with_permission(resource: "customers", action: "read")

    assert_raises AnnesAccess::NotAuthorizedError do
      AnnesAccess.authorize!(account, :destroy, :customers)
    end
  end

  test "custom rule can refine final decision" do
    account = account_with_permission(resource: "customers", action: "read")
    AnnesAccess.configuration.custom_rule = ->(principal:, action:, resource:, record:, allowed:) {
      allowed && record == :visible && principal == account && action == "read" && resource == "customers"
    }

    assert AnnesAccess.can?(account, :read, :customers, record: :visible)
    assert_not AnnesAccess.can?(account, :read, :customers, record: :hidden)
  end

  private
    def account_with_permission(resource:, action:)
      account = Account.create!(email: "#{resource}-#{action}@example.com")
      role = AnnesAccess::Role.create!(key: "#{resource}_#{action}", name: "#{resource} #{action}")
      permission = AnnesAccess::Permission.create!(resource:, action:)
      AnnesAccess::RolePermission.create!(role:, permission:)
      AnnesAccess::Assignment.create!(principal: account, role:)
      account
    end
end
