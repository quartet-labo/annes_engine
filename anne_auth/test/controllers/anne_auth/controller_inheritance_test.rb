require "test_helper"

class AnneAuth::ControllerInheritanceTest < ActionDispatch::IntegrationTest
  test "host authentication controllers inherit engine implementations" do
    assert_operator CustomerAccounts::SessionsController, :<, AnneAuth::Accounts::SessionsController
    assert_operator CustomerAccounts::OmniauthCallbacksController, :<, AnneAuth::Accounts::OmniauthCallbacksController
    assert_operator CustomerAccounts::EmailVerificationsController, :<, AnneAuth::Accounts::EmailVerificationsController
    assert_operator CustomerAccounts::PasswordResetsController, :<, AnneAuth::Accounts::PasswordResetsController
  end

  test "engine registration route has a controller implementation" do
    assert_equal AnneAuth::Accounts::RegistrationsController,
      "AnneAuth::Accounts::RegistrationsController".constantize
  end
end
