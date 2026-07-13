require "test_helper"

class InternalRoutesTest < ActionDispatch::IntegrationTest
  test "public entry points redirect to the internal admin area" do
    get "/"
    assert_redirected_to "/admin/reservations/schedule"

    get "/dashboard"
    assert_redirected_to "/admin/reservations/schedule"

    get "/auth/login"
    assert_redirected_to "/admin/login"
  end

  test "admin login is available" do
    get admin_login_path

    assert_response :success
    assert_includes response.body, "管理者ログイン"
    assert_select "form[action=?][method=?]", admin_session_path, "post"
  end

  test "admin area redirects anonymous users to login" do
    get "/admin"

    assert_redirected_to "/admin/login"
  end
end
