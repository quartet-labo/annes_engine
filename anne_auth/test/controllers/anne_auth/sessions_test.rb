require "test_helper"
require "securerandom"

class AnneAuth::SessionsTest < ActionDispatch::IntegrationTest
  test "creates and restores user session" do
    user = User.create!(
      name: "User",
      email: "user-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    assert_difference -> { AnneAuth::Session.count }, 1 do
      post "/session", params: { email: user.email, password: "password123" }
    end

    auth_session = user.sessions.order(:id).last
    assert_instance_of AnneAuth::Session, auth_session
    assert_equal user, auth_session.user
    assert_redirected_to "/"
  end
end
