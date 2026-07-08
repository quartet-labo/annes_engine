require "test_helper"
require "securerandom"

class AnneAuth::AdminSessionsTest < ActionDispatch::IntegrationTest
  test "creates and restores legacy admin session without a host Session wrapper" do
    assert_not Object.const_defined?(:Session, false)

    admin_user = AdminUser.create!(
      name: "Admin",
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    assert_difference -> { AnneAuth::AdminSession.count }, 1 do
      post "/admin/session", params: { email: admin_user.email, password: "password123" }
    end

    admin_session = admin_user.sessions.order(:id).last
    assert_instance_of AnneAuth::AdminSession, admin_session
    assert_equal admin_user, admin_session.admin_user
    assert_redirected_to "/admin"

    restored_session = AnneAuth.configuration.admin_session_class.includes(:admin_user).find_by(id: admin_session.id)
    assert_equal admin_user, restored_session.admin_user
  end
end
