require_relative "../../test_helper"

class AnneAccess::AuthorizationTest < ActionController::TestCase
  tests DummyController

  def setup
    AnneAccess.reset_configuration!
    super
    @account = Account.create!(email: "controller@example.com")
    @role = AnneAccess::Role.create!(key: "staff", name: "Staff")
    permission = AnneAccess::Permission.create!(resource: "customers", action: "read")
    AnneAccess::RolePermission.create!(role: @role, permission:)
    AnneAccess::Assignment.create!(principal: @account, role: @role)
    @controller.current_account = @account
  end

  def teardown
    super
    AnneAccess.reset_configuration!
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

  test "default principal lookup prefers current account over current user" do
    @controller.current_user = Account.create!(email: "unassigned-user@example.com")

    assert @controller.can_access?(:read, :customers)
  end

  test "configured principal resolver can prefer current user" do
    session_account = Account.create!(email: "session-account@example.com")
    user = Account.create!(email: "business-user@example.com")
    AnneAccess::Assignment.create!(principal: user, role: @role)

    @controller.current_account = session_account
    @controller.current_user = user
    AnneAccess.configuration.principal_resolver = ->(controller) { controller.send(:current_user) }

    assert @controller.can_access?(:read, :customers)
  end

  test "configured principal resolver returning nil denies by default" do
    AnneAccess.configuration.principal_resolver = ->(_controller) { nil }

    assert_not @controller.can_access?(:read, :customers)
    assert_raises AnneAccess::NotAuthorizedError do
      @controller.authorize_access!(:read, :customers)
    end
  end
end
