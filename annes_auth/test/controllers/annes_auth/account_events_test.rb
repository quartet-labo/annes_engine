require "test_helper"

class AnnesAuth::AccountEventsTest < ActionDispatch::IntegrationTest
  CODE = "123456"

  class RecordingAccountMailer
    class << self
      attr_accessor :deliveries

      def with(params)
        new(params)
      end

      def reset!
        self.deliveries = []
      end
    end

    def initialize(params)
      @params = params
      @action_name = nil
    end

    def verification
      @action_name = :verification
      self
    end

    def password_reset
      @action_name = :password_reset
      self
    end

    def invitation
      @action_name = :invitation
      self
    end

    def deliver_now
      self.class.deliveries << @params.merge(action_name: @action_name)
      true
    end
  end

  setup do
    @verified = customer_accounts(:verified)
    @unverified = customer_accounts(:unverified)
    @verified.update!(email_verified_at: 1.day.ago, disabled_at: nil)
    @unverified.update!(email_verified_at: nil, disabled_at: nil)
    [ @verified, @unverified ].each do |account|
      account.account_sessions.destroy_all
      account.account_password_reset_tokens.destroy_all
      account.account_verification_tokens.destroy_all
      account.account_invitation_tokens.destroy_all
    end
    @original_google_oauth_enabled = AnnesAuth.configuration.google_oauth_enabled
    @original_google_oauth_client_id = AnnesAuth.configuration.google_oauth_client_id
    @original_google_oauth_client_secret = AnnesAuth.configuration.google_oauth_client_secret
    @original_account_mailer_class_name = AnnesAuth.configuration.account_mailer_class_name
    AnnesAuth.configuration.account_mailer_class_name =
      "AnnesAuth::AccountEventsTest::RecordingAccountMailer"
    RecordingAccountMailer.reset!
    AnnesAuth::Current.reset
  end

  teardown do
    AnnesAuth.configuration.google_oauth_enabled = @original_google_oauth_enabled
    AnnesAuth.configuration.google_oauth_client_id = @original_google_oauth_client_id
    AnnesAuth.configuration.google_oauth_client_secret = @original_google_oauth_client_secret
    AnnesAuth.configuration.account_mailer_class_name = @original_account_mailer_class_name
    RecordingAccountMailer.reset!
    AnnesAuth::Current.reset
  end

  test "emits password sign in events for successful credential login" do
    events = capture_account_events do
      post "/auth/account_session", params: { email: @verified.email, password: "password-123" }
    end

    assert_redirected_to "/"
    account_session = @verified.account_sessions.order(:created_at).last
    payload = only_event(events)
    assert_event payload, "sign_in", account: @verified, account_session:, auth_method: "password"
    refute_includes payload.inspect, "password-123"
  end

  test "does not emit account events for invalid credential login" do
    events = capture_account_events do
      post "/auth/account_session", params: { email: @verified.email, password: "wrong-password" }
    end

    assert_redirected_to "/auth/login"
    assert_empty events
  end

  test "emits google sign in events for successful oauth login" do
    AnnesAuth.configuration.google_oauth_enabled = true
    AnnesAuth.configuration.google_oauth_client_id = "google-client-id"
    AnnesAuth.configuration.google_oauth_client_secret = "google-client-secret"

    events = capture_account_events do
      post "/auth/auth/google_oauth2/callback",
        env: { "omniauth.auth" => google_auth_hash(uid: "event-google-uid", email: "event-google@example.com") }
    end

    account = CustomerAccount.find_by!(email: "event-google@example.com")
    account_session = account.account_sessions.order(:created_at).last
    payload = only_event(events)
    assert_event payload, "sign_in", account:, account_session:, auth_method: "google_oauth", provider: "google"
  end

  test "emits sign out events before destroying the account session" do
    sign_in(@verified)
    account_session = @verified.account_sessions.order(:created_at).last
    AnnesAuth::Current.reset

    events = capture_account_events do
      delete "/auth/logout"
    end

    assert_redirected_to "/auth/login"
    payload = only_event(events)
    assert_event payload, "sign_out", account: @verified, account_session:, auth_method: nil
  end

  test "emits password reset requested only for existing active accounts" do
    events = capture_account_events do
      post "/auth/password_reset", params: { email: @verified.email }
    end

    assert_redirected_to "/auth/login"
    payload = only_event(events)
    assert_event payload, "password_reset_requested", account: @verified, auth_method: "password_reset"

    missing_events = capture_account_events do
      post "/auth/password_reset", params: { email: "missing@example.com" }
    end

    assert_redirected_to "/auth/login"
    assert_empty missing_events
  end

  test "emits password reset completed events without reset secrets" do
    sign_in(@verified)
    account_session = @verified.account_sessions.order(:created_at).last
    _password_reset_token, plain_token = CustomerAccountPasswordResetToken.issue_for(@verified)

    events = capture_account_events do
      patch "/auth/password_reset", params: {
        token: plain_token,
        password: "new-password-123",
        password_confirmation: "new-password-123"
      }
    end

    assert_redirected_to "/auth/login"
    payload = only_event(events)
    assert_event payload, "password_reset_completed", account: @verified, account_session:, auth_method: "password_reset"
    refute_includes payload.inspect, plain_token
    refute_includes payload.inspect, "new-password-123"
  end

  test "emits email verified events without verification codes" do
    sign_in(@unverified, expected_redirect: "/auth/email_verification/pending")
    account_session = @unverified.account_sessions.order(:created_at).last
    create_verification_token(@unverified)

    events = capture_account_events do
      post "/auth/email_verification/verify", params: { otp: CODE }
    end

    assert_redirected_to "/"
    payload = only_event(events)
    assert_event payload, "email_verified", account: @unverified, account_session:, auth_method: "email_verification"
    refute_includes payload.inspect, CODE
  end

  test "emits invitation sent and accepted events without invitation tokens" do
    sent_events = capture_account_events do
      @delivery_result = AnnesAuth::Accounts::InvitationDelivery.call(@unverified)
    end

    assert_equal :delivered, @delivery_result.status
    sent_payload = only_event(sent_events)
    assert_event sent_payload, "invitation_sent", account: @unverified, auth_method: "invitation"
    plain_token = RecordingAccountMailer.deliveries.last.fetch(:plain_token)
    assert CustomerAccountInvitationToken.lookup(plain_token).success?
    refute_includes sent_payload.inspect, plain_token

    get "/auth/invitation", params: { token: plain_token }
    assert_redirected_to "/auth/invitation/edit"

    accepted_events = capture_account_events do
      patch "/auth/invitation", params: {
        password: "accepted-password-123",
        password_confirmation: "accepted-password-123"
      }
    end

    assert_redirected_to "/auth/login"
    accepted_payload = only_event(accepted_events)
    assert_event accepted_payload, "invitation_accepted", account: @unverified, auth_method: "invitation"
    refute_includes accepted_payload.inspect, plain_token
    refute_includes accepted_payload.inspect, "accepted-password-123"
  end

  private
    def capture_account_events
      events = []

      ActiveSupport::Notifications.subscribed(
        ->(*args) { events << ActiveSupport::Notifications::Event.new(*args).payload },
        AnnesAuth::AccountEvent::EVENT_NAME
      ) do
        yield
      end

      events
    end

    def only_event(events)
      assert_equal 1, events.size
      events.first
    end

    def assert_event(payload, event, account:, account_session: nil, auth_method:, provider: nil)
      assert_equal event, payload.fetch(:event)
      assert_equal account.to_param, payload.fetch(:account_id)
      assert_equal account.class.name, payload.fetch(:account_class)
      assert_equal account.email, payload.fetch(:account_email)
      assert_payload_value payload, :session_id, account_session&.to_param
      assert_payload_value payload, :auth_method, auth_method
      assert_payload_value payload, :provider, provider
      assert_equal "success", payload.fetch(:status)
      assert payload.key?(:ip_address)
      assert payload.key?(:user_agent)
      assert_kind_of Hash, payload.fetch(:metadata)
    end

    def assert_payload_value(payload, key, expected)
      if expected.nil?
        assert_nil payload.fetch(key)
      else
        assert_equal expected, payload.fetch(key)
      end
    end

    def sign_in(account, expected_redirect: nil)
      post "/auth/account_session", params: { email: account.email, password: "password-123" }
      assert_response :redirect
      assert_redirected_to expected_redirect if expected_redirect
    end

    def create_verification_token(account)
      account.account_verification_tokens.create!(
        token_digest: CustomerAccountVerificationToken.digest_for(account, CODE),
        expires_at: 15.minutes.from_now,
        attempt_count: 0
      )
    end

    def google_auth_hash(uid:, email:, email_verified: true)
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
