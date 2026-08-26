require_relative "../../test_helper"

class AnnesAdmin::ConfigurationTest < AnnesAdmin::TestCase
  test "defaults require explicit authentication" do
    assert_equal "Admin", AnnesAdmin.configuration.site_name
    assert_equal 25, AnnesAdmin.configuration.default_per_page
    assert_equal 100, AnnesAdmin.configuration.max_per_page

    assert_raises(AnnesAdmin::ConfigurationError) do
      AnnesAdmin.configuration.authenticate!(Object.new)
    end
  end

  test "stores authentication and user hooks" do
    controller = Object.new
    user = Object.new

    AnnesAdmin.configure do |config|
      config.authenticate_with { |passed_controller| passed_controller.equal?(controller) }
      config.current_user { user }
    end

    assert AnnesAdmin.configuration.authenticate!(controller)
    assert_same user, AnnesAdmin.configuration.current_user_for(controller)
  end

  test "authorization defaults to allowing authenticated users" do
    assert AnnesAdmin.configuration.authorized?(action: :index)

    AnnesAdmin.configure do |config|
      config.authorize_with { |context| context.fetch(:action) == :show }
    end

    assert AnnesAdmin.configuration.authorized?(action: :show)
    assert_not AnnesAdmin.configuration.authorized?(action: :edit)
  end

  test "top-level resource delegates to configuration resources" do
    resource = AnnesAdmin.resource :customers, model: "Customer" do
      label "Customers"
    end

    assert_same resource, AnnesAdmin.configuration.resources.fetch(:customers)
    assert_equal "Customers", resource.label
  end

  test "resource source context is restored after registration" do
    AnnesAdmin.configuration.with_resource_source(:loader) do
      AnnesAdmin.configuration.resource :customers, model: "Customer"
    end

    AnnesAdmin.configuration.resources.remove_source(:loader)
    AnnesAdmin.configuration.resource :projects, model: "Project"

    assert AnnesAdmin.configuration.resources.key?(:projects)
  end
end
