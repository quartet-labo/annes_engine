require "test_helper"

class AnnesAuth::Accounts::GoogleAuthenticationTest < ActiveSupport::TestCase
  test "host compatibility service inherits engine implementation" do
    assert_operator CustomerAccounts::GoogleAuthentication, :<, AnnesAuth::Accounts::GoogleAuthentication
  end

  test "engine service creates a verified account for a new google email" do
    auth = google_auth(uid: "engine-google-new-uid", email: "engine-google-new@example.com")

    assert_difference "CustomerAccount.count", 1 do
      result = AnnesAuth::Accounts::GoogleAuthentication.call(auth)

      assert result.success?
      assert result.profile_required?
      assert_equal "engine-google-new@example.com", result.account.email
    end
  end

  test "does not link google login to an unverified password account" do
    account = customer_accounts(:unverified)
    auth = google_auth(uid: "unverified-google-uid", email: account.email)

    assert_no_difference "CustomerAccountIdentity.count" do
      result = AnnesAuth::Accounts::GoogleAuthentication.call(auth)
      assert_equal :unverified_account, result.status
    end
    assert_not account.reload.email_verified?
  end

  test "does not verify an unverified account through an existing identity" do
    account = customer_accounts(:unverified)
    account.account_identities.create!(provider: "google", uid: "existing-google-uid", email: account.email)

    result = AnnesAuth::Accounts::GoogleAuthentication.call(
      google_auth(uid: "existing-google-uid", email: account.email)
    )

    assert_equal :unverified_account, result.status
    assert_not account.reload.email_verified?
  end

  test "links a verified password account and reuses its google identity" do
    account = customer_accounts(:verified)
    auth = google_auth(uid: "verified-google-uid", email: account.email)

    first = AnnesAuth::Accounts::GoogleAuthentication.call(auth)
    second = AnnesAuth::Accounts::GoogleAuthentication.call(auth)

    assert first.success?
    assert second.success?
    assert_equal account, first.account
    assert_equal first.identity, second.identity
  end

  private
    def google_auth(uid:, email:, email_verified: true, name: "Google User")
      OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid:,
        info: {
          email:,
          email_verified:,
          name:
        },
        extra: {
          id_info: {
            sub: uid,
            email:,
            email_verified:,
            name:
          }
        }
      )
    end
end
