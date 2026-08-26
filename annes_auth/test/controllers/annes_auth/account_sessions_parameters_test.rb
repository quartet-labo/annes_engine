require "test_helper"

class AnnesAuth::AccountSessionsParametersTest < ActionDispatch::IntegrationTest
  setup do
    AnnesAuth::Current.reset
    customer_accounts(:verified).account_sessions.destroy_all
  end

  teardown do
    AnnesAuth::Current.reset
  end

  test "standard login form parameters do not emit unpermitted parameter notifications" do
    notifications = []
    original_action = ActionController::Parameters.action_on_unpermitted_parameters
    ActionController::Parameters.action_on_unpermitted_parameters = :log
    subscriber = ActiveSupport::Notifications.subscribe("unpermitted_parameters.action_controller") do |*args|
      notifications << ActiveSupport::Notifications::Event.new(*args).payload
    end

    account = customer_accounts(:verified)

    assert_difference -> { account.account_sessions.count }, 1 do
      post "/auth/account_session", params: {
        authenticity_token: "test-token",
        email: account.email,
        password: "password-123",
        commit: "ログイン"
      }
    end

    assert_response :redirect
    assert_empty notifications
  ensure
    ActionController::Parameters.action_on_unpermitted_parameters = original_action
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  test "passes only email and password to account authentication" do
    controller = AnnesAuth::Accounts::SessionsController.new
    controller.params = ActionController::Parameters.new(
      authenticity_token: "test-token",
      email: "verified@example.com",
      password: "password-123",
      commit: "ログイン",
      unexpected: "ignored"
    )
    authentication_params = controller.send(:session_params)

    assert_predicate authentication_params, :permitted?
    assert_equal(
      { "email" => "verified@example.com", "password" => "password-123" },
      authentication_params.to_h
    )
  end

  test "invalid credentials do not create an account session" do
    assert_no_difference "CustomerSession.count" do
      post "/auth/account_session", params: {
        email: "verified@example.com",
        password: "wrong"
      }
    end

    assert_redirected_to "/auth/login"
    assert_equal "メールアドレスまたはパスワードが正しくありません。", flash[:alert]
  end
end
