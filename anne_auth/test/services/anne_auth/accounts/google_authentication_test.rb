require "test_helper"

class AnneAuth::Accounts::GoogleAuthenticationTest < ActiveSupport::TestCase
  test "host compatibility service inherits engine implementation" do
    assert_operator CustomerAccounts::GoogleAuthentication, :<, AnneAuth::Accounts::GoogleAuthentication
  end

  test "engine service creates a verified account for a new google email" do
    auth = google_auth(uid: "engine-google-new-uid", email: "engine-google-new@example.com")

    assert_difference "CustomerAccount.count", 1 do
      result = AnneAuth::Accounts::GoogleAuthentication.call(auth)

      assert result.success?
      assert result.profile_required?
      assert_equal "engine-google-new@example.com", result.account.email
    end
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
