require "test_helper"

class AnnesAuth::AccountMailerTest < ActionMailer::TestCase
  test "host compatibility mailer inherits engine implementation" do
    assert_operator CustomerAccountMailer, :<, AnnesAuth::AccountMailer
  end

  test "engine verification email includes code" do
    mail = AnnesAuth::AccountMailer.with(
      account: customer_accounts(:unverified),
      plain_code: "123456"
    ).verification

    assert_equal "メールアドレス認証のご案内", mail.subject
    assert_equal [ customer_accounts(:unverified).email ], mail.to
    assert_match "123456", mail.text_part.decoded
    assert_match "123456", mail.html_part.decoded
    assert_match "15分", mail.text_part.decoded
    assert_no_match "email_verification?token=", mail.text_part.decoded
  end

  test "invitation email contains the configured activation URL and expiry in both parts" do
    account = customer_accounts(:unverified)
    plain_token = "plain-invitation-token-1234567890"
    configured_calls = []
    original_account_invitation_url = AnnesAuth.configuration.account_invitation_url
    AnnesAuth.configuration.account_invitation_url = lambda do |mailer, token|
      configured_calls << [ mailer, token ]
      "https://accounts.example.test/auth/invitation?token=#{token}"
    end

    mail = AnnesAuth::AccountMailer.with(account:, plain_token:).invitation
    text_body = mail.text_part.decoded
    html_body = mail.html_part.decoded
    activation_url = "https://accounts.example.test/auth/invitation?token=#{plain_token}"

    assert_equal "アカウント設定のご案内", mail.subject
    assert_equal [ account.email ], mail.to
    assert mail.multipart?
    assert_equal 1, configured_calls.size
    assert_instance_of AnnesAuth::AccountMailer, configured_calls.first.first
    assert_equal plain_token, configured_calls.first.last

    [ text_body, html_body ].each do |body|
      assert_includes body, "アカウント設定"
      assert_includes body, activation_url
      assert_includes body, "1時間"
      assert_equal 1, body.scan(plain_token).size
      assert_no_match(/Admin|User|role|管理者|ユーザー|ロール/i, body)
      assert_not_includes body, "password-123"
      assert_not_includes body, account.password_digest
    end
  ensure
    AnnesAuth.configuration.account_invitation_url = original_account_invitation_url
  end
end
