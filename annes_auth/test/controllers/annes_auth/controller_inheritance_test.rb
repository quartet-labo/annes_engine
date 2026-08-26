require "test_helper"

class AnnesAuth::ControllerInheritanceTest < ActionDispatch::IntegrationTest
  test "host authentication controllers inherit engine implementations" do
    assert_operator CustomerAccounts::SessionsController, :<, AnnesAuth::Accounts::SessionsController
    assert_operator CustomerAccounts::OmniauthCallbacksController, :<, AnnesAuth::Accounts::OmniauthCallbacksController
    assert_operator CustomerAccounts::EmailVerificationsController, :<, AnnesAuth::Accounts::EmailVerificationsController
    assert_operator CustomerAccounts::PasswordResetsController, :<, AnnesAuth::Accounts::PasswordResetsController
  end

  test "engine registration route has a controller implementation" do
    assert_equal AnnesAuth::Accounts::RegistrationsController,
      "AnnesAuth::Accounts::RegistrationsController".constantize
  end
end
