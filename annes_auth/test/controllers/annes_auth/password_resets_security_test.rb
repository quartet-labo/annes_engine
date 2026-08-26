require "test_helper"

class AnnesAuth::PasswordResetsSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @account = customer_accounts(:verified)
    @account.account_sessions.destroy_all
    @account.account_password_reset_tokens.destroy_all
    AnnesAuth::Current.reset
  end

  teardown do
    AnnesAuth::Current.reset
  end

  test "issuing a password reset token expires older active tokens" do
    old_token, old_plain_token = CustomerAccountPasswordResetToken.issue_for(@account)

    new_token, new_plain_token = CustomerAccountPasswordResetToken.issue_for(@account)

    assert old_token.reload.used?
    assert_not new_token.reload.used?

    get "/auth/password_reset/edit", params: { token: old_plain_token }
    assert_redirected_to "/auth/password_reset/new"

    get "/auth/password_reset/edit", params: { token: new_plain_token }
    assert_response :success
  end

  test "successful password reset expires active tokens and destroys account sessions" do
    sign_in
    account_session = @account.account_sessions.order(:created_at).last
    password_reset_token, plain_token = CustomerAccountPasswordResetToken.issue_for(@account)
    extra_token = @account.account_password_reset_tokens.create!(
      token_digest: CustomerAccountPasswordResetToken.digest("extra-reset-token"),
      expires_at: 1.hour.from_now
    )

    patch "/auth/password_reset", params: {
      token: plain_token,
      password: "new-password-123",
      password_confirmation: "new-password-123"
    }

    assert_redirected_to "/auth/login"
    assert password_reset_token.reload.used?
    assert extra_token.reload.used?
    assert_not CustomerSession.exists?(account_session.id)

    get "/auth/logout/confirm"
    assert_redirected_to "/auth/login"
  end

  private
    def sign_in
      post "/auth/account_session", params: { email: @account.email, password: "password-123" }
      assert_response :redirect
    end
end
