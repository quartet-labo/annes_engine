require "test_helper"

class ReservationManagementAcceptanceTest < ActionDispatch::IntegrationTest
  test "all seed accounts can log in and open the reservation schedule" do
    with_reservation_management_seeds do
      %w[admin operator viewer].each_with_index do |role, index|
        sign_in_seed_account("#{role}@example.com", remote_addr: "192.0.2.#{20 + index}")

        get "/admin/reservations/schedule", params: { date: Date.current.iso8601 }
        assert_response :success

        delete "/admin/logout"
        assert_response :see_other
      end
    end
  end

  test "seed operator can create and cancel a reservation" do
    with_reservation_management_seeds do
      operator = Account.find_by!(email: "operator@example.com")
      customer = Customer.find_by!(customer_number: "C-DEMO-001")
      resource = ReservationResource.find_by!(name: "貸出機材")
      starts_at = Time.zone.local(*(Date.current + 2.days).then { |date| [ date.year, date.month, date.day, 14, 0 ] })
      ends_at = starts_at + 1.hour
      sign_in_seed_account(operator.email)

      assert_difference("Reservation.count", 1) do
        post "/admin/reservations", params: {
          reservation: {
            customer_id: customer.id,
            reservation_resource_id: resource.id,
            starts_at: starts_at.strftime("%Y-%m-%dT%H:%M"),
            ends_at: ends_at.strftime("%Y-%m-%dT%H:%M"),
            party_size: 1,
            channel: "counter",
            memo: "受け入れテストから登録"
          }
        }
      end

      reservation = Reservation.order(:id).last
      assert_redirected_to "/admin/reservations/#{reservation.id}"
      assert_equal "confirmed", reservation.status

      patch "/admin/reservations/#{reservation.id}/cancel", params: {
        reservation: {
          lock_version: reservation.lock_version,
          cancellation_reason: "受け入れテストで取消"
        }
      }

      assert_redirected_to "/admin/reservations/#{reservation.id}"
      assert_equal [ "canceled", operator.id, "受け入れテストで取消" ],
        reservation.reload.values_at(:status, :canceled_by_id, :cancellation_reason)
    end
  end

  test "seed viewer is read only" do
    with_reservation_management_seeds do
      reservation = Reservation.find_by!(reservation_number: "R-DEMO-001")
      customer = Customer.find_by!(customer_number: "C-DEMO-001")
      resource = ReservationResource.find_by!(name: "貸出機材")
      date = Date.current + 2.days
      sign_in_seed_account("viewer@example.com")

      get "/admin/reservations/#{reservation.id}"
      assert_response :success
      assert_select "a, button", text: "予約を編集", count: 0
      assert_select "a, button", text: "予約を取消", count: 0

      assert_no_difference("Reservation.count") do
        post "/admin/reservations", params: {
          reservation: {
            customer_id: customer.id,
            reservation_resource_id: resource.id,
            starts_at: Time.zone.local(date.year, date.month, date.day, 16).strftime("%Y-%m-%dT%H:%M"),
            ends_at: Time.zone.local(date.year, date.month, date.day, 17).strftime("%Y-%m-%dT%H:%M"),
            party_size: 1,
            channel: "other"
          }
        }
      end
      assert_response :forbidden

      assert_no_changes -> { reservation.reload.memo } do
        patch "/admin/reservations/#{reservation.id}", params: {
          reservation: { memo: "閲覧者による更新", lock_version: reservation.lock_version }
        }
      end
      assert_response :forbidden
    end
  end
end
