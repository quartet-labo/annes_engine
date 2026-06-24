require "test_helper"

class AnneAuth::AuthenticationConcernsTest < ActionDispatch::IntegrationTest
  test "host concerns include engine concerns" do
    assert_equal AnneAuth::AdminAuthentication, ApplicationController.instance_method(:current_admin_session).owner
    assert_equal AnneAuth::AccountAuthentication, ApplicationController.instance_method(:current_account_session).owner
    assert_equal CustomerAuthentication, ApplicationController.instance_method(:current_customer_session).owner
  end

  test "host current is engine current" do
    assert_equal AnneAuth::Current, Current
  end
end
