require "test_helper"

class AnneAuth::AccountSessionsRedirectTest < ActionDispatch::IntegrationTest
  setup do
    @original_after_account_login_path = AnneAuth.configuration.after_account_login_path
    AnneAuth::Current.reset
    customer_accounts(:verified).account_sessions.destroy_all
    customer_accounts(:unverified).account_sessions.destroy_all
  end

  teardown do
    AnneAuth.configuration.after_account_login_path = @original_after_account_login_path
    AnneAuth::Current.reset
  end

  test "renders login for guests" do
    get "/auth/login"

    assert_response :success
    assert_select "h1", "ログイン"
  end

  test "redirects verified account from login to configured account path" do
    AnneAuth.configuration.after_account_login_path =
      ->(controller, _account) { controller.main_app.dashboard_path }

    sign_in(customer_accounts(:verified))

    get "/auth/login"

    assert_redirected_to "/dashboard"
  end

  test "redirects unverified account from login to email verification pending" do
    sign_in(customer_accounts(:unverified), expected_redirect: "/auth/email_verification/pending")

    get "/auth/login"

    assert_redirected_to "/auth/email_verification/pending"
    assert_equal "メール認証を完了してください。", flash[:alert]
  end

  test "redirects verified account from signup to configured account path" do
    AnneAuth.configuration.after_account_login_path =
      ->(controller, _account) { controller.main_app.dashboard_path }

    sign_in(customer_accounts(:verified))

    get "/auth/signup"

    assert_redirected_to "/dashboard"
  end

  test "redirects unverified account from signup to email verification pending" do
    sign_in(customer_accounts(:unverified), expected_redirect: "/auth/email_verification/pending")

    get "/auth/signup"

    assert_redirected_to "/auth/email_verification/pending"
    assert_equal "メール認証を完了してください。", flash[:alert]
  end

  test "redirects unverified account away from verified host screens" do
    sign_in(customer_accounts(:unverified), expected_redirect: "/auth/email_verification/pending")

    get "/verified"

    assert_redirected_to "/auth/email_verification/pending"
    assert_equal "メール認証を完了してください。", flash[:alert]
  end

  test "redirects verified account from email verification pending to configured account path" do
    AnneAuth.configuration.after_account_login_path =
      ->(controller, _account) { controller.main_app.dashboard_path }

    sign_in(customer_accounts(:verified))

    get "/auth/email_verification/pending"

    assert_redirected_to "/dashboard"
    assert_equal "メール認証は完了しています。", flash[:notice]
  end

  test "creates account sessions with expiration metadata" do
    travel_to Time.zone.local(2026, 1, 1, 12, 0, 0) do
      account = customer_accounts(:verified)

      sign_in(account)

      account_session = account.account_sessions.order(:created_at).last
      assert_not_nil account_session.last_used_at
      assert_equal 2.weeks.from_now, account_session.expires_at
    end
  end

  test "destroys expired account sessions and treats the request as unauthenticated" do
    account = customer_accounts(:verified)
    sign_in(account)
    account_session = account.account_sessions.order(:created_at).last
    account_session.update!(expires_at: 1.minute.ago)
    AnneAuth::Current.reset

    get "/auth/logout/confirm"

    assert_redirected_to "/auth/login"
    assert_not CustomerSession.exists?(account_session.id)
  end

  private
    def sign_in(account, expected_redirect: nil)
      post "/auth/account_session", params: { email: account.email, password: "password-123" }
      assert_response :redirect
      assert_redirected_to expected_redirect if expected_redirect
    end
end
