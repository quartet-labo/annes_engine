require "test_helper"

class AnneAuth::DefaultViewsTest < ActionDispatch::IntegrationTest
  test "renders account authentication views from the engine" do
    get "/auth/login"
    assert_response :success
    assert_select "h1", "ログイン"

    get "/auth/signup"
    assert_response :success
    assert_select "h1", "アカウント作成"

    get "/auth/password_reset/new"
    assert_response :success
    assert_select "h1", "パスワード再設定"
  end

  test "renders password reset edit view with a valid token" do
    _password_reset_token, plain_token =
      CustomerAccountPasswordResetToken.issue_for(customer_accounts(:verified))

    get "/auth/password_reset/edit", params: { token: plain_token }
    assert_response :success
    assert_select "h1", "新しいパスワード"
    assert_select "input[name=token][value=?]", plain_token
  end

  test "renders logged-in account views from the engine" do
    post "/auth/account_session",
      params: { email: customer_accounts(:unverified).email, password: "password-123" }
    assert_redirected_to "/auth/email_verification/pending"

    get "/auth/email_verification/pending"
    assert_response :success
    assert_select "h1", "メール認証"

    get "/auth/logout/confirm"
    assert_response :success
    assert_select "h1", "ログアウト"
  end
end
