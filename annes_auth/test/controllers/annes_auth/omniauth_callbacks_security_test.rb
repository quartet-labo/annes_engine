require "test_helper"

class AnnesAuth::OmniauthCallbacksSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @original_google_oauth_enabled = AnnesAuth.configuration.google_oauth_enabled
    @original_google_oauth_client_id = AnnesAuth.configuration.google_oauth_client_id
    @original_google_oauth_client_secret = AnnesAuth.configuration.google_oauth_client_secret
    AnnesAuth::Current.reset
  end

  teardown do
    AnnesAuth.configuration.google_oauth_enabled = @original_google_oauth_enabled
    AnnesAuth.configuration.google_oauth_client_id = @original_google_oauth_client_id
    AnnesAuth.configuration.google_oauth_client_secret = @original_google_oauth_client_secret
    AnnesAuth::Current.reset
  end

  test "does not process google callback when oauth is disabled" do
    AnnesAuth.configuration.google_oauth_enabled = false
    AnnesAuth.configuration.google_oauth_client_id = nil
    AnnesAuth.configuration.google_oauth_client_secret = nil

    assert_no_difference "CustomerAccount.count" do
      post "/auth/auth/google_oauth2/callback", env: { "omniauth.auth" => google_auth_hash }
    end

    assert_redirected_to "/auth/login"
    assert_equal "Googleログインに失敗しました。", flash[:alert]
  end

  test "processes google callback when oauth is configured" do
    AnnesAuth.configuration.google_oauth_enabled = true
    AnnesAuth.configuration.google_oauth_client_id = "google-client-id"
    AnnesAuth.configuration.google_oauth_client_secret = "google-client-secret"

    assert_difference "CustomerAccount.count", 1 do
      post "/auth/auth/google_oauth2/callback", env: { "omniauth.auth" => google_auth_hash(email: "oauth-enabled@example.com") }
    end

    assert_redirected_to "/"
    assert_equal "oauth-enabled@example.com", CustomerAccount.order(:created_at).last.email
  end

  private
    def google_auth_hash(uid: "google-uid", email: "google-user@example.com", email_verified: true)
      OmniAuth::AuthHash.new(
        provider: "google_oauth2",
        uid:,
        info: {
          email:,
          email_verified:,
          name: "Google User"
        },
        extra: {
          id_info: {
            sub: uid,
            email:,
            email_verified:,
            name: "Google User"
          }
        }
      )
    end
end
