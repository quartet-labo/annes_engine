require "test_helper"

class AnneAuth::OmniauthCallbacksSecurityTest < ActionDispatch::IntegrationTest
  setup do
    @original_google_oauth_enabled = AnneAuth.configuration.google_oauth_enabled
    @original_google_oauth_client_id = AnneAuth.configuration.google_oauth_client_id
    @original_google_oauth_client_secret = AnneAuth.configuration.google_oauth_client_secret
    AnneAuth::Current.reset
  end

  teardown do
    AnneAuth.configuration.google_oauth_enabled = @original_google_oauth_enabled
    AnneAuth.configuration.google_oauth_client_id = @original_google_oauth_client_id
    AnneAuth.configuration.google_oauth_client_secret = @original_google_oauth_client_secret
    AnneAuth::Current.reset
  end

  test "does not process google callback when oauth is disabled" do
    AnneAuth.configuration.google_oauth_enabled = false
    AnneAuth.configuration.google_oauth_client_id = nil
    AnneAuth.configuration.google_oauth_client_secret = nil

    assert_no_difference "CustomerAccount.count" do
      post "/auth/auth/google_oauth2/callback", env: { "omniauth.auth" => google_auth_hash }
    end

    assert_redirected_to "/auth/login"
    assert_equal "Googleログインに失敗しました。", flash[:alert]
  end

  test "processes google callback when oauth is configured" do
    AnneAuth.configuration.google_oauth_enabled = true
    AnneAuth.configuration.google_oauth_client_id = "google-client-id"
    AnneAuth.configuration.google_oauth_client_secret = "google-client-secret"

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
