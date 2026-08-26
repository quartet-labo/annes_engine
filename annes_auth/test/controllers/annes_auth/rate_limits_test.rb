require "test_helper"

class AnnesAuth::RateLimitsTest < ActionDispatch::IntegrationTest
  class SilentVerificationMailer
    def self.with(**_params)
      new
    end

    def verification
      self
    end

    def password_reset
      self
    end

    def deliver_now
      true
    end
  end

  setup do
    Rails.cache.clear
    @original_account_mailer_class_name = AnnesAuth.configuration.account_mailer_class_name
    AnnesAuth.configuration.account_mailer_class_name = "AnnesAuth::RateLimitsTest::SilentVerificationMailer"
    customer_accounts(:unverified).account_sessions.destroy_all
  end

  teardown do
    Rails.cache.clear
    AnnesAuth.configuration.account_mailer_class_name = @original_account_mailer_class_name
    AnnesAuth::Current.reset
  end

  test "limits repeated login attempts for the same email across source IPs" do
    email_variants = [
      " verified@example.com ",
      "VERIFIED@example.com",
      "Verified@Example.Com",
      "verified@example.com ",
      " VERIFIED@EXAMPLE.COM "
    ]

    email_variants.each_with_index do |email, index|
      post "/auth/account_session",
        params: { email:, password: "wrong" },
        headers: remote_addr(index)
      assert_redirected_to "/auth/login"
      assert_equal "メールアドレスまたはパスワードが正しくありません。", flash[:alert]
    end

    post "/auth/account_session",
      params: { email: "verified@example.com", password: "wrong" },
      headers: remote_addr(6)

    assert_redirected_to "/auth/login"
    assert_equal "時間をおいて再度お試しください。", flash[:alert]
  end

  test "limits repeated password reset requests for the same email across source IPs" do
    3.times do |index|
      post "/auth/password_reset",
        params: { email: "verified@example.com" },
        headers: remote_addr(index)
      assert_redirected_to "/auth/login"
    end

    post "/auth/password_reset",
      params: { email: "verified@example.com" },
      headers: remote_addr(4)

    assert_redirected_to "/auth/password_reset/new"
    assert_equal "時間をおいて再度お試しください。", flash[:alert]
  end

  test "limits email verification resend for the current account" do
    sign_in(customer_accounts(:unverified))

    3.times do
      post "/auth/email_verification/resend"
      assert_response :see_other
      assert_redirected_to "/auth/email_verification/pending"
    end

    post "/auth/email_verification/resend"

    assert_redirected_to "/auth/email_verification/pending"
    assert_equal "時間をおいて再度お試しください。", flash[:alert]
  end

  test "limits repeated signup attempts from the same IP" do
    5.times do |index|
      post "/auth/account_registration",
        params: { account: { email: "signup-rate-limit-#{index}@example.com", password: "", password_confirmation: "" } }
      assert_response :unprocessable_entity
    end

    post "/auth/account_registration",
      params: { account: { email: "signup-rate-limit-final@example.com", password: "", password_confirmation: "" } }

    assert_redirected_to "/auth/signup"
    assert_equal "時間をおいて再度お試しください。", flash[:alert]
  end

  private
    def sign_in(account)
      post "/auth/account_session", params: { email: account.email, password: "password-123" }
      assert_response :redirect
      Rails.cache.clear
    end

    def remote_addr(index)
      { "REMOTE_ADDR" => "192.0.2.#{index}" }
    end
end
