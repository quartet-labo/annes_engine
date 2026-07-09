require_relative "test_helper"

class AnneAccess::ConfigurationTest < AnneAccess::TestCase
  test "defaults to explicit deny oriented settings" do
    configuration = AnneAccess.configuration

    assert_empty configuration.principal_class_names
    assert_empty configuration.super_admin_role_keys
    assert_nil configuration.default_role_key
    assert_equal({ index: :read, show: :read, new: :create, edit: :update }, configuration.action_aliases)
    assert_nil configuration.custom_rule
  end

  test "configure updates settings" do
    AnneAccess.configure do |config|
      config.principal_class_names = [ "Account" ]
      config.super_admin_role_keys = [ "admin" ]
      config.default_role_key = "viewer"
    end

    assert_equal [ "Account" ], AnneAccess.configuration.principal_class_names
    assert_equal [ "admin" ], AnneAccess.configuration.super_admin_role_keys
    assert_equal "viewer", AnneAccess.configuration.default_role_key
  end
end
