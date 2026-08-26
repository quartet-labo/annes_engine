require "test_helper"

class ReservationRoutePrecedenceTest < ActionDispatch::IntegrationTest
  test "root and admin home redirect to the host reservation schedule" do
    get "/"
    assert_redirected_to "/admin/reservations/schedule"

    get "/admin/home"
    assert_redirected_to "/admin/reservations/schedule"
  end

  test "host reservation routes are recognized before the AnnesAdmin mount" do
    assert_equal(
      { controller: "admin/reservations", action: "schedule" },
      recognized_route("/admin/reservations/schedule", :get)
    )
    assert_equal(
      { controller: "admin/reservations", action: "index" },
      recognized_route("/admin/reservations", :get)
    )
    assert_equal(
      { controller: "admin/reservations", action: "cancel" },
      recognized_route("/admin/reservations/123/cancel", :patch).slice(:controller, :action)
    )
  end

  test "reservation destroy route is not defined" do
    sign_in_as_role(:admin)

    delete "/admin/reservations/123"

    assert_response :not_found
  end

  private
    def recognized_route(path, method)
      Rails.application.routes.recognize_path(path, method:).symbolize_keys.slice(:controller, :action)
    end
end
