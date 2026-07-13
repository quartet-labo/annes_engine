require "test_helper"

class ReservationResourceTest < ActiveSupport::TestCase
  test "accepts known kinds and exposes labels and an active scope" do
    resource = ReservationResource.create!(name: "会議室A", kind: "room", capacity: 6)
    inactive = ReservationResource.create!(name: "旧会議室", kind: "facility", active: false)

    assert_equal "会議室A", resource.display_name
    assert_equal "部屋", resource.kind_label
    assert_equal [ resource ], ReservationResource.active.to_a
    assert_not_includes ReservationResource.active, inactive

    resource.kind = "unknown"
    assert_not resource.valid?
    assert resource.errors.added?(:kind, :inclusion, value: "unknown")
  end

  test "requires a positive capacity" do
    resource = ReservationResource.new(name: "会議室A", kind: "room", capacity: 0)

    assert_not resource.valid?
    assert resource.errors.added?(:capacity, :greater_than_or_equal_to, value: 0, count: 1)
  end

  test "cannot reduce capacity below a future blocking reservation party size" do
    customer = Customer.create!(name: "予約 顧客")
    resource = ReservationResource.create!(name: "会議室A", kind: "room", capacity: 6)
    Reservation.create!(
      customer: customer,
      reservation_resource: resource,
      starts_at: 1.day.from_now.beginning_of_hour,
      ends_at: 1.day.from_now.beginning_of_hour + 1.hour,
      party_size: 5
    )

    resource.capacity = 4

    assert_not resource.valid?
    assert resource.errors.added?(:capacity, :greater_than_or_equal_to, count: 5)
  end

  test "can reduce capacity when only terminal or past reservations exceed it" do
    customer = Customer.create!(name: "予約 顧客")
    resource = ReservationResource.create!(name: "会議室A", kind: "room", capacity: 6)
    Reservation.create!(
      customer: customer,
      reservation_resource: resource,
      starts_at: 2.days.ago.beginning_of_hour,
      ends_at: 2.days.ago.beginning_of_hour + 1.hour,
      party_size: 5,
      status: "completed"
    )

    resource.capacity = 2

    assert resource.valid?
  end

  test "cannot be destroyed when reservations exist" do
    customer = Customer.create!(name: "予約 顧客")
    resource = ReservationResource.create!(name: "会議室A", kind: "room", capacity: 4)
    Reservation.create!(
      customer: customer,
      reservation_resource: resource,
      starts_at: Time.zone.parse("2026-07-14 10:00"),
      ends_at: Time.zone.parse("2026-07-14 11:00")
    )

    assert_not resource.destroy
    assert ReservationResource.exists?(resource.id)
    assert resource.errors.added?(:base, :"restrict_dependent_destroy.has_many", record: "reservations")
  end
end
