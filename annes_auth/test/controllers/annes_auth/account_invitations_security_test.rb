require "test_helper"

class AnnesAuth::AccountInvitationsSecurityTest < ActionDispatch::IntegrationTest
  DEFAULT_REFERRER_POLICY = "strict-origin-when-cross-origin"
  INVALID_INVITATION_MESSAGE = "招待リンクが無効または期限切れです。"

  setup do
    @account = customer_accounts(:unverified)
    @account.update!(email_verified_at: nil, disabled_at: nil)
    @account.account_invitation_tokens.destroy_all
    AnnesAuth::Current.reset
  end

  teardown do
    AnnesAuth::Current.reset
  end

  test "valid token entry redirects to a token-free edit URL without consuming the invitation" do
    invitation, plain_token = CustomerAccountInvitationToken.issue_for(@account)

    get "/auth/invitation", params: { token: plain_token }

    assert_response :see_other
    assert_redirected_to "/auth/invitation/edit"
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_not invitation.reload.used?
    assert_not_includes response.location, plain_token
    assert_not_includes response.headers.fetch("Set-Cookie"), plain_token

    follow_redirect!

    assert_response :success
    assert_equal DEFAULT_REFERRER_POLICY, response.headers["Referrer-Policy"]
    assert_select "h1", "アカウント設定"
    assert_select "form[action=?]", "/auth/invitation"
    assert_select "input[name=token]", count: 0
    assert_not_includes response.body, plain_token
  end

  test "same-origin update succeeds with CSRF origin verification enabled" do
    invitation, plain_token = CustomerAccountInvitationToken.issue_for(@account)

    with_forgery_protection do
      get "/auth/invitation", params: { token: plain_token }
      assert_response :see_other

      follow_redirect!
      assert_response :success
      assert_equal DEFAULT_REFERRER_POLICY, response.headers["Referrer-Policy"]
      authenticity_token = css_select("input[name=authenticity_token]").first["value"]

      patch "/auth/invitation",
        params: {
          authenticity_token:,
          password: "new-password-123",
          password_confirmation: "new-password-123"
        },
        headers: { "Origin" => "http://www.example.com" }
    end

    assert_response :see_other
    assert_redirected_to "/auth/login"
    assert invitation.reload.used?
    assert @account.reload.email_verified?
  end

  test "invalid invitation states share one generic response" do
    assert_invalid_entry("invalid-token")

    used_invitation, used_plain_token = CustomerAccountInvitationToken.issue_for(@account)
    used_invitation.mark_used!
    assert_invalid_entry(used_plain_token)

    _expired_invitation, expired_plain_token = CustomerAccountInvitationToken.issue_for(
      @account,
      expires_at: 1.second.ago
    )
    assert_invalid_entry(expired_plain_token)

    _disabled_invitation, disabled_plain_token = CustomerAccountInvitationToken.issue_for(@account)
    @account.update!(disabled_at: Time.current)
    assert_invalid_entry(disabled_plain_token)

    @account.update!(disabled_at: nil, email_verified_at: nil)
    _verified_invitation, verified_plain_token = CustomerAccountInvitationToken.issue_for(@account)
    @account.update!(email_verified_at: Time.current)
    assert_invalid_entry(verified_plain_token)
  end

  test "edit requires invitation state established by the token entry" do
    get "/auth/invitation/edit"

    assert_invalid_response(referrer_policy: DEFAULT_REFERRER_POLICY)
  end

  test "edit revalidates invitation state and clears stale session state" do
    invitation, plain_token = CustomerAccountInvitationToken.issue_for(@account)
    get "/auth/invitation", params: { token: plain_token }
    assert_response :see_other

    invitation.mark_used!
    get "/auth/invitation/edit"
    assert_invalid_response(referrer_policy: DEFAULT_REFERRER_POLICY)

    get "/auth/invitation/edit"
    assert_invalid_response(referrer_policy: DEFAULT_REFERRER_POLICY)
  end

  test "invitation token parameters are filtered" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter(token: "plain-invitation-token")

    assert_equal "[FILTERED]", filtered[:token]
  end

  private
    def assert_invalid_entry(plain_token)
      get "/auth/invitation", params: { token: plain_token }

      assert_invalid_response(referrer_policy: "no-referrer")
      assert_not_includes response.location, plain_token
      assert_not_includes response.body, plain_token
    end

    def assert_invalid_response(referrer_policy:)
      assert_response :see_other
      assert_redirected_to "/auth/login"
      assert_equal INVALID_INVITATION_MESSAGE, flash[:alert]
      assert_equal referrer_policy, response.headers["Referrer-Policy"]
    end

    def with_forgery_protection
      original_allow_forgery_protection = ActionController::Base.allow_forgery_protection
      original_origin_check = ActionController::Base.forgery_protection_origin_check
      ActionController::Base.allow_forgery_protection = true
      ActionController::Base.forgery_protection_origin_check = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = original_allow_forgery_protection
      ActionController::Base.forgery_protection_origin_check = original_origin_check
    end
end
