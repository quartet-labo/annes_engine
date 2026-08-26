require "test_helper"

class AnnesAuth::PasswordPolicyTest < ActionDispatch::IntegrationTest
  test "rejects short passwords during registration" do
    assert_no_difference "CustomerAccount.count" do
      post "/auth/account_registration", params: {
        account: {
          email: "registration-short-password@example.com",
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "rejects short passwords during password reset" do
    _password_reset_token, plain_token =
      CustomerAccountPasswordResetToken.issue_for(customer_accounts(:verified))

    patch "/auth/password_reset", params: {
      token: plain_token,
      password: "short",
      password_confirmation: "short"
    }

    assert_response :unprocessable_entity
  end
end
