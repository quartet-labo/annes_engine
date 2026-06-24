require_relative "../../test_helper"

class AnneAdmin::AuthenticationTest < AnneAdmin::IntegrationTest
  test "requires authentication hook" do
    assert_raises(AnneAdmin::ConfigurationError) do
      engine_get "/"
    end
  end

  test "allows access when authentication hook permits" do
    AnneAdmin.configure do |config|
      config.authenticate_with { true }
    end

    engine_get "/"

    assert_engine_response :success
    assert_includes engine_response.body, "管理画面"
  end

  test "uses current user hook in layout" do
    user = Struct.new(:email).new("admin@example.com")

    AnneAdmin.configure do |config|
      config.authenticate_with { true }
      config.current_user { user }
    end

    engine_get "/"

    assert_engine_response :success
    assert_includes engine_response.body, "admin@example.com"
  end

  private
    def engine_session
      @engine_session ||= ActionDispatch::Integration::Session.new(AnneAdmin::Engine)
    end

    def engine_get(...)
      engine_session.get(...)
    end

    def engine_response
      engine_session.response
    end

    def assert_engine_response(status)
      assert_equal engine_status_code(status), engine_response.status, engine_response.body
    end

    def engine_status_code(status)
      Rack::Utils.status_code(status == :success ? :ok : status)
    end
end
