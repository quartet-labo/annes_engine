require "test_helper"

class AnnesAuth::AccountEventTest < ActiveSupport::TestCase
  Request = Struct.new(:remote_ip, :user_agent, keyword_init: true)

  setup do
    @account = customer_accounts(:verified)
    @session = @account.account_sessions.create!(
      user_agent: "Existing browser",
      ip_address: "192.0.2.10",
      expires_at: 1.hour.from_now,
      last_used_at: Time.current
    )
    @request = Request.new(remote_ip: "203.0.113.10", user_agent: "Mozilla/5.0")
  end

  test "emits a normalized account event payload" do
    assert_equal "annes_auth.account_event", AnnesAuth::AccountEvent::EVENT_NAME

    payload = capture_event do
      AnnesAuth::AccountEvent.emit(
        :sign_in,
        account: @account,
        account_session: @session,
        request: @request,
        auth_method: :password,
        provider: :credentials,
        status: :success,
        metadata: { source: :login_form }
      )
    end

    assert_equal "sign_in", payload.fetch(:event)
    assert_equal @account.to_param, payload.fetch(:account_id)
    assert_equal @account.class.name, payload.fetch(:account_class)
    assert_equal @account.email, payload.fetch(:account_email)
    assert_equal @session.to_param, payload.fetch(:session_id)
    assert_equal "password", payload.fetch(:auth_method)
    assert_equal "credentials", payload.fetch(:provider)
    assert_equal "203.0.113.10", payload.fetch(:ip_address)
    assert_equal "Mozilla/5.0", payload.fetch(:user_agent)
    assert_equal "success", payload.fetch(:status)
    assert_equal({ source: "login_form" }, payload.fetch(:metadata))
  end

  test "keeps payload keys stable when optional context is nil" do
    payload = capture_event do
      AnnesAuth::AccountEvent.emit(:password_reset_requested)
    end

    assert_equal({
      event: "password_reset_requested",
      account_id: nil,
      account_class: nil,
      account_email: nil,
      session_id: nil,
      auth_method: nil,
      provider: nil,
      ip_address: nil,
      user_agent: nil,
      status: "success",
      metadata: {}
    }, payload)
  end

  test "filters credential and bearer-token metadata" do
    payload = capture_event do
      AnnesAuth::AccountEvent.emit(
        :invitation_sent,
        account: @account,
        metadata: {
          delivery_id: 123,
          password: "password-123",
          password_confirmation: "password-123",
          token: "plain-token",
          plain_token: "plain-token",
          plain_code: "123456",
          otp: "123456",
          cookie: "signed-cookie",
          session_cookie: "signed-cookie",
          oauth_token: "oauth-secret"
        }
      )
    end

    assert_equal({ delivery_id: 123 }, payload.fetch(:metadata))
    event_text = payload.inspect
    refute_includes event_text, "password-123"
    refute_includes event_text, "plain-token"
    refute_includes event_text, "123456"
    refute_includes event_text, "signed-cookie"
    refute_includes event_text, "oauth-secret"
  end

  private
    def capture_event
      payloads = []

      ActiveSupport::Notifications.subscribed(
        ->(*args) { payloads << ActiveSupport::Notifications::Event.new(*args).payload },
        AnnesAuth::AccountEvent::EVENT_NAME
      ) do
        yield
      end

      assert_equal 1, payloads.size
      payloads.first
    end
end
