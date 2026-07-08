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
    sign_in(customer_accounts(:unverified))

    get "/auth/login"

    assert_redirected_to "/auth/email_verification/pending"
    assert_equal "メール認証を完了してください。", flash[:alert]
  end

  private
    def sign_in(account)
      post "/auth/account_session", params: { email: account.email, password: "password-123" }
      assert_response :redirect
    end
end
