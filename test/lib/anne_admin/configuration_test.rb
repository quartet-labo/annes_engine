require_relative "../../test_helper"

class AnneAdmin::ConfigurationTest < AnneAdmin::TestCase
  test "defaults require explicit authentication" do
    assert_equal "Admin", AnneAdmin.configuration.site_name
    assert_equal 25, AnneAdmin.configuration.default_per_page
    assert_equal 100, AnneAdmin.configuration.max_per_page

    assert_raises(AnneAdmin::ConfigurationError) do
      AnneAdmin.configuration.authenticate!(Object.new)
    end
  end

  test "stores authentication and user hooks" do
    controller = Object.new
    user = Object.new

    AnneAdmin.configure do |config|
      config.authenticate_with { |passed_controller| passed_controller.equal?(controller) }
      config.current_user { user }
    end

    assert AnneAdmin.configuration.authenticate!(controller)
    assert_same user, AnneAdmin.configuration.current_user_for(controller)
  end

  test "authorization defaults to allowing authenticated users" do
    assert AnneAdmin.configuration.authorized?(action: :index)

    AnneAdmin.configure do |config|
      config.authorize_with { |context| context.fetch(:action) == :show }
    end

    assert AnneAdmin.configuration.authorized?(action: :show)
    assert_not AnneAdmin.configuration.authorized?(action: :edit)
  end
end
