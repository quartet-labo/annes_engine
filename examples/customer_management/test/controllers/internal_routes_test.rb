require "test_helper"

class InternalRoutesTest < ActionDispatch::IntegrationTest
  test "public entry points redirect to the internal admin area" do
    get "/"
    assert_redirected_to "/admin"

    get "/dashboard"
    assert_redirected_to "/admin"

    get "/auth/login"
    assert_redirected_to "/admin/login"
  end

  test "admin login is available" do
    get admin_login_path

    assert_response :success
    assert_includes response.body, "管理者ログイン"
  end
end
