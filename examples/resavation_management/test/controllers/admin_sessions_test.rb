require "test_helper"

class AdminSessionsTest < ActionDispatch::IntegrationTest
  setup do
    @account = Account.create!(
      email: "operator@example.com",
      password: "password-1234",
      password_confirmation: "password-1234"
    )
  end

  test "valid credentials create an admin session" do
    post admin_session_path, params: { email: @account.email, password: "password-1234" }

    assert_redirected_to admin_root_path
    assert_not_nil @account.reload.last_sign_in_at

    follow_redirect!
    assert_redirected_to "/admin/"

    follow_redirect!
    assert_response :success
  end

  test "invalid credentials return to login" do
    post admin_session_path, params: { email: @account.email, password: "wrong-password" }

    assert_redirected_to admin_login_path
    assert_equal "メールアドレスまたはパスワードが正しくありません。", flash[:alert]
  end

  test "disabled accounts cannot log in" do
    @account.update!(disabled_at: Time.current)

    post admin_session_path, params: { email: @account.email, password: "password-1234" }

    assert_redirected_to admin_login_path
    assert_equal "メールアドレスまたはパスワードが正しくありません。", flash[:alert]
  end

  test "logout terminates the session" do
    post admin_session_path, params: { email: @account.email, password: "password-1234" }
    delete admin_logout_path

    assert_redirected_to admin_login_path

    get "/admin"
    assert_redirected_to admin_login_path
  end

  test "anne access remains deny by default" do
    assert_not AnneAccess.can?(@account, :read, :reservations)
  end
end
