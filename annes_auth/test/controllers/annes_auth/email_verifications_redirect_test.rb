require "test_helper"

class AnnesAuth::EmailVerificationsRedirectTest < ActionDispatch::IntegrationTest
  CODE = "123456"

  class SilentVerificationMailer
    def self.with(account:, plain_code:)
      new
    end

    def verification
      self
    end

    def deliver_now
      true
    end
  end

  setup do
    @original_after_account_email_verification_path = AnnesAuth.configuration.after_account_email_verification_path
    @original_account_mailer_class_name = AnnesAuth.configuration.account_mailer_class_name
    @account = customer_accounts(:unverified)
    @account.update!(email_verified_at: nil)
    @account.account_sessions.destroy_all
    @account.account_verification_tokens.destroy_all
  end

  teardown do
    AnnesAuth.configuration.after_account_email_verification_path = @original_after_account_email_verification_path
    AnnesAuth.configuration.account_mailer_class_name = @original_account_mailer_class_name
    AnnesAuth::Current.reset
  end

  test "redirects successful verification with see other to a gettable host path" do
    sign_in
    create_verification_token

    post "/auth/email_verification/verify", params: { otp: CODE }

    assert_response :see_other
    assert_redirected_to "/"
    assert_not_equal "/auth/email_verification/verify", redirect_path

    follow_redirect!
    assert_response :success
    assert @account.reload.email_verified?
  end

  test "uses configured after email verification path" do
    verified_account = nil
    AnnesAuth.configuration.after_account_email_verification_path =
      lambda do |controller, account|
        verified_account = account
        controller.main_app.dashboard_path
      end

    sign_in
    create_verification_token

    post "/auth/email_verification/verify", params: { otp: CODE }

    assert_response :see_other
    assert_redirected_to "/dashboard"
    assert_equal @account.id, verified_account.id
    assert verified_account.email_verified?

    follow_redirect!
    assert_response :success
  end

  test "redirects invalid code back to pending with see other" do
    sign_in
    create_verification_token

    post "/auth/email_verification/verify", params: { otp: "000000" }

    assert_response :see_other
    assert_redirected_to "/auth/email_verification/pending"

    follow_redirect!
    assert_response :success
  end

  test "redirects expired code back to pending with see other" do
    sign_in
    create_verification_token(expires_at: 1.minute.ago)

    post "/auth/email_verification/verify", params: { otp: CODE }

    assert_response :see_other
    assert_redirected_to "/auth/email_verification/pending"

    follow_redirect!
    assert_response :success
  end

  test "redirects too many attempts back to pending with see other" do
    sign_in
    create_verification_token(attempt_count: CustomerAccountVerificationToken::MAX_ATTEMPTS)

    post "/auth/email_verification/verify", params: { otp: CODE }

    assert_response :see_other
    assert_redirected_to "/auth/email_verification/pending"

    follow_redirect!
    assert_response :success
  end

  test "redirects resend back to pending with see other" do
    AnnesAuth.configuration.account_mailer_class_name =
      "AnnesAuth::EmailVerificationsRedirectTest::SilentVerificationMailer"

    sign_in

    post "/auth/email_verification/resend"

    assert_response :see_other
    assert_redirected_to "/auth/email_verification/pending"
  end

  test "accepts a code digested with the pre-rename salt" do
    @account.account_verification_tokens.create!(
      token_digest: legacy_verification_digest(CODE),
      expires_at: 15.minutes.from_now,
      attempt_count: 0
    )

    result = CustomerAccountVerificationToken.lookup_for(@account, CODE)

    assert_equal :ok, result.status
  end

  private
    def sign_in
      post "/auth/account_session", params: { email: @account.email, password: "password-123" }
      assert_redirected_to "/auth/email_verification/pending"
    end

    def create_verification_token(code: CODE, expires_at: 15.minutes.from_now, attempt_count: 0)
      @account.account_verification_tokens.create!(
        token_digest: CustomerAccountVerificationToken.digest_for(@account, code),
        expires_at:,
        attempt_count:
      )
    end

    def legacy_verification_digest(code)
      secret = Rails.application.key_generator.generate_key("anne_auth/account_verification_code", 32)
      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{@account.id}:#{code}")
    end

    def redirect_path
      URI.parse(response.location).path
    end
end
