require_relative "test_helper"

class AnnesAccess::ConfigurationTest < AnnesAccess::TestCase
  test "defaults to explicit deny oriented settings" do
    configuration = AnnesAccess.configuration

    assert_empty configuration.principal_class_names
    assert_empty configuration.super_admin_role_keys
    assert_nil configuration.default_role_key
    assert_equal({ index: :read, show: :read, new: :create, edit: :update }, configuration.action_aliases)
    assert_nil configuration.custom_rule
    assert_nil configuration.principal_resolver
  end

  test "configure updates settings" do
    resolver = ->(controller) { controller.send(:current_user) }

    AnnesAccess.configure do |config|
      config.principal_class_names = [ "Account" ]
      config.super_admin_role_keys = [ "admin" ]
      config.default_role_key = "viewer"
      config.principal_resolver = resolver
    end

    assert_equal [ "Account" ], AnnesAccess.configuration.principal_class_names
    assert_equal [ "admin" ], AnnesAccess.configuration.super_admin_role_keys
    assert_equal "viewer", AnnesAccess.configuration.default_role_key
    assert_same resolver, AnnesAccess.configuration.principal_resolver
  end
end
