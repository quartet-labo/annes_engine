require "test_helper"

class AnneAuth::EngineTest < ActiveSupport::TestCase
  test "engine is isolated and configured" do
    assert_equal "anne_auth", AnneAuth::Engine.engine_name
    assert_respond_to AnneAuth::Engine.routes.url_helpers, :account_login_path
    assert_respond_to AnneAuth::Engine.routes.url_helpers, :account_invitation_path
    assert_respond_to AnneAuth::Engine.routes.url_helpers, :edit_account_invitation_path
    assert_instance_of AnneAuth::Configuration, AnneAuth.configuration
  end
end
