require "test_helper"

class CustomerTest < ActiveSupport::TestCase
  test "assigns a customer number and exposes an active scope" do
    customer = Customer.create!(name: "山田 太郎")
    inactive = Customer.create!(name: "停止 顧客", active: false)

    assert_match(/\AC-[0-9A-F]{8}\z/, customer.customer_number)
    assert_equal [ customer ], Customer.active.to_a
    assert_equal "#{customer.customer_number} 山田 太郎", customer.display_name
    assert_not_includes Customer.active, inactive
  end

  test "requires a name and validates an optional email" do
    customer = Customer.new(name: "", email: "not-an-email")

    assert_not customer.valid?
    assert customer.errors.added?(:name, :blank)
    assert customer.errors.added?(:email, :invalid, value: "not-an-email")

    assert Customer.new(name: "メールなし", email: "").valid?
  end

  test "cannot be destroyed when reservations exist" do
    customer = Customer.create!(name: "予約 顧客")
    resource = ReservationResource.create!(name: "会議室A", kind: "room", capacity: 4)
    Reservation.create!(
      customer: customer,
      reservation_resource: resource,
      starts_at: Time.zone.parse("2026-07-14 10:00"),
      ends_at: Time.zone.parse("2026-07-14 11:00"),
      party_size: 2
    )

    assert_not customer.destroy
    assert Customer.exists?(customer.id)
    assert customer.errors.added?(:base, :restrict_dependent_destroy, record: "reservations")
  end
end
