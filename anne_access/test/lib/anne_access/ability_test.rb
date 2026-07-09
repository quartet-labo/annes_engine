require_relative "../../test_helper"

class AnneAccess::AbilityTest < AnneAccess::TestCase
  test "allows action through assigned role permission" do
    account = account_with_permission(resource: "customers", action: "read")

    assert AnneAccess.can?(account, :read, :customers)
  end

  test "denies action without permission" do
    account = account_with_permission(resource: "customers", action: "read")

    assert_not AnneAccess.can?(account, :update, :customers)
  end

  test "manage allows standard actions for same resource" do
    account = account_with_permission(resource: "projects", action: "manage")

    assert AnneAccess.can?(account, :read, :projects)
    assert AnneAccess.can?(account, :update, :projects)
    assert_not AnneAccess.can?(account, :read, :customers)
    assert_not AnneAccess.can?(account, :approve, :projects)
  end

  test "denies nil principal and unknown resource" do
    account = account_with_permission(resource: "customers", action: "read")

    assert_not AnneAccess.can?(nil, :read, :customers)
    assert_not AnneAccess.can?(account, :read, :unknown)
  end

  test "authorize raises when denied" do
    account = account_with_permission(resource: "customers", action: "read")

    assert_raises AnneAccess::NotAuthorizedError do
      AnneAccess.authorize!(account, :destroy, :customers)
    end
  end

  test "custom rule can refine final decision" do
    account = account_with_permission(resource: "customers", action: "read")
    AnneAccess.configuration.custom_rule = ->(principal:, action:, resource:, record:, allowed:) {
      allowed && record == :visible && principal == account && action == "read" && resource == "customers"
    }

    assert AnneAccess.can?(account, :read, :customers, record: :visible)
    assert_not AnneAccess.can?(account, :read, :customers, record: :hidden)
  end

  private
    def account_with_permission(resource:, action:)
      account = Account.create!(email: "#{resource}-#{action}@example.com")
      role = AnneAccess::Role.create!(key: "#{resource}_#{action}", name: "#{resource} #{action}")
      permission = AnneAccess::Permission.create!(resource:, action:)
      AnneAccess::RolePermission.create!(role:, permission:)
      AnneAccess::Assignment.create!(principal: account, role:)
      account
    end
end
