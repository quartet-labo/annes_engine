require "test_helper"

class AnneAuth::AccountMailerTest < ActionMailer::TestCase
  test "host compatibility mailer inherits engine implementation" do
    assert_operator CustomerAccountMailer, :<, AnneAuth::AccountMailer
  end

  test "engine verification email includes code" do
    mail = AnneAuth::AccountMailer.with(
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
end
