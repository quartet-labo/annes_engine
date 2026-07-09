require_relative "../../test_helper"

class AnneAccess::AuthorizationTest < ActionController::TestCase
  tests DummyController

  def setup
    super
    @account = Account.create!(email: "controller@example.com")
    role = AnneAccess::Role.create!(key: "staff", name: "Staff")
    permission = AnneAccess::Permission.create!(resource: "customers", action: "read")
    AnneAccess::RolePermission.create!(role:, permission:)
    AnneAccess::Assignment.create!(principal: @account, role:)
    @controller.current_account = @account
  end

  test "current ability uses current account" do
    assert @controller.can_access?(:read, :customers)
    assert_not @controller.can_access?(:destroy, :customers)
  end

  test "authorize access raises when unauthorized" do
    assert_raises AnneAccess::NotAuthorizedError do
      @controller.authorize_access!(:destroy, :customers)
    end
  end

  test "current user fallback is supported" do
    @controller.current_account = nil
    @controller.current_user = @account

    assert @controller.can_access?(:read, :customers)
  end
end
