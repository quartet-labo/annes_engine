require "test_helper"

class AdminBoundaryTest < ActionDispatch::IntegrationTest
  teardown do
    AnnesInquiry.configuration.admin_authenticator = nil
    AnnesInquiry.configuration.admin_authorizer = nil
  end

  test "missing authentication or authorization hooks deny access" do
    get "/inquiry/admin/forms"
    assert_response :forbidden
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    get "/inquiry/admin/forms"
    assert_response :forbidden
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { false }
    get "/inquiry/admin/forms"
    assert_response :forbidden
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { user == :admin }
    get "/inquiry/admin/forms"
    assert_response :success
  end
end
