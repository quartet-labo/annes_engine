require "test_helper"

class InternalRoutesTest < ActionDispatch::IntegrationTest
  test "public entry points route to customer and staff areas" do
    get "/"
    assert_redirected_to "/customer"

    get "/dashboard"
    assert_redirected_to "/customer"

    get "/customer"
    assert_response :success
    assert_includes response.body, "Restaurant loyalty customer dashboard"
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
