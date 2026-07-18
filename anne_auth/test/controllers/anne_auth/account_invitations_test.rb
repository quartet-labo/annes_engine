require "test_helper"

class AnneAuth::AccountInvitationsTest < ActionDispatch::IntegrationTest
  setup do
    @account = customer_accounts(:unverified)
    @account.update!(email_verified_at: nil, disabled_at: nil)
    @account.account_invitation_tokens.destroy_all
    @account.account_sessions.destroy_all
    AnneAuth::Current.reset
  end

  teardown do
    AnneAuth::Current.reset
  end

  test "password validation error can be corrected with the same invitation session" do
    invitation, plain_token = CustomerAccountInvitationToken.issue_for(@account)
    enter_invitation(plain_token)

    patch "/auth/invitation", params: {
      password: "short",
      password_confirmation: "short"
    }

    assert_response :unprocessable_entity
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_select ".auth-errors"
    assert_not invitation.reload.used?
    assert_not @account.reload.email_verified?

    patch "/auth/invitation", params: {
      password: "new-password-123",
      password_confirmation: "new-password-123"
    }

    assert_response :see_other
    assert_redirected_to "/auth/login"
    assert_equal "アカウント設定が完了しました。ログインしてください。", flash[:notice]
    assert invitation.reload.used?
    assert @account.reload.email_verified?
    assert @account.authenticate("new-password-123")
    assert_empty @account.account_sessions

    follow_redirect!
    assert_response :success
    assert_select "h1", "ログイン"
  end

  test "missing password parameters render validation errors without consuming the invitation" do
    invitation, plain_token = CustomerAccountInvitationToken.issue_for(@account)
    enter_invitation(plain_token)

    patch "/auth/invitation"

    assert_response :unprocessable_entity
    assert_select ".auth-errors"
    assert_not invitation.reload.used?
    assert_not @account.reload.email_verified?
  end

  test "successful activation clears the current target account session cookie" do
    sign_in(@account, expected_redirect: "/auth/email_verification/pending")
    account_session = @account.account_sessions.order(:created_at).last
    invitation, plain_token = CustomerAccountInvitationToken.issue_for(@account)
    enter_invitation(plain_token)

    patch "/auth/invitation", params: {
      password: "new-password-123",
      password_confirmation: "new-password-123"
    }

    assert_response :see_other
    assert invitation.reload.used?
    assert_not CustomerSession.exists?(account_session.id)

    get "/auth/logout/confirm"
    assert_redirected_to "/auth/login"
  end

  test "activating an invitation does not clear a different account session" do
    other_account = customer_accounts(:verified)
    other_account.account_sessions.destroy_all
    sign_in(other_account)
    other_session = other_account.account_sessions.order(:created_at).last
    _invitation, plain_token = CustomerAccountInvitationToken.issue_for(@account)
    enter_invitation(plain_token)

    patch "/auth/invitation", params: {
      password: "new-password-123",
      password_confirmation: "new-password-123"
    }

    assert_response :see_other
    assert CustomerSession.exists?(other_session.id)

    get "/auth/logout/confirm"
    assert_response :success
  end

  private
    def enter_invitation(plain_token)
      get "/auth/invitation", params: { token: plain_token }
      assert_response :see_other
      assert_redirected_to "/auth/invitation/edit"
    end

    def sign_in(account, expected_redirect: nil)
      post "/auth/account_session", params: { email: account.email, password: "password-123" }
      assert_response :redirect
      assert_redirected_to expected_redirect if expected_redirect
    end
end
