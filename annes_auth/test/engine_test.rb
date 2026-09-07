require "test_helper"

class AnnesAuth::EngineTest < ActiveSupport::TestCase
  test "engine is isolated and configured" do
    assert_equal "annes_auth", AnnesAuth::Engine.engine_name
    assert_respond_to AnnesAuth::Engine.routes.url_helpers, :account_login_path
    assert_respond_to AnnesAuth::Engine.routes.url_helpers, :account_invitation_path
    assert_respond_to AnnesAuth::Engine.routes.url_helpers, :edit_account_invitation_path
    assert_instance_of AnnesAuth::Configuration, AnnesAuth.configuration
  end

  test "exposes only the AnnesAuth public namespace" do
    assert_equal "1.0.1", AnnesAuth::VERSION
    refute Object.const_defined?(:AnneAuth)
  end

  test "does not provide the legacy require path" do
    assert_raises(LoadError) { require "anne_auth" }
  end

  test "engine does not expose a public invitation issuance route" do
    assert_raises(ActionController::RoutingError) do
      AnnesAuth::Engine.routes.recognize_path("/invitation", method: :post)
    end
  end
end
