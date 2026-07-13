require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  setup do
    @customer = Customer.create!(name: "山田 太郎")
    @resource = ReservationResource.create!(name: "会議室A", kind: "room", capacity: 4)
    @starts_at = Time.zone.parse("2026-07-14 10:00")
  end

  test "assigns a reservation number and defaults to confirmed and other" do
    reservation = build_reservation

    assert reservation.save
    assert_match(/\AR-[0-9A-F]{8}\z/, reservation.reservation_number)
    assert_equal "confirmed", reservation.status
    assert_equal "other", reservation.channel
    assert_equal 0, reservation.lock_version
    assert_equal "#{reservation.reservation_number} 山田 太郎", reservation.display_name
    assert_equal "予約確定", reservation.status_label
    assert_equal "その他", reservation.channel_label
  end

  test "defines the reservation lifecycle with AASM events" do
    assert_equal Reservation::STATUSES.sort, Reservation.aasm.states.map { |state| state.name.to_s }.sort
    assert_equal %i[cancel complete confirm mark_no_show], Reservation.aasm.events.map(&:name).sort

    provisional = build_reservation(status: "provisional")
    assert_predicate provisional, :may_confirm?
    assert_predicate provisional, :may_cancel?
    assert_not provisional.may_complete?
    assert_not provisional.may_mark_no_show?

    provisional.confirm!
    assert_equal "confirmed", provisional.reload.status
  end

  test "uses AASM guards for completion and no show events" do
    reservation = build_reservation
    reservation.save!

    travel_to @starts_at - 1.minute do
      assert_not reservation.may_complete?
      assert_not reservation.may_mark_no_show?
    end

    travel_to @starts_at do
      assert_predicate reservation, :may_complete?
      assert_predicate reservation, :may_mark_no_show?
    end
  end

  test "uses the AASM cancel callback to persist cancellation metadata" do
    actor = Account.create!(email: "aasm-cancel@example.com", password: "password123456")
    reservation = build_reservation
    reservation.save!
    canceled_at = Time.zone.parse("2026-07-14 09:00")

    reservation.cancel!(actor, "体調不良", canceled_at)

    reservation.reload
    assert_equal "canceled", reservation.status
    assert_equal actor, reservation.canceled_by
    assert_equal canceled_at, reservation.canceled_at
    assert_equal "体調不良", reservation.cancellation_reason
  end

  test "validates known status and channel" do
    reservation = build_reservation(status: "unknown", channel: "fax")

    assert_not reservation.valid?
    assert reservation.errors.added?(:status, :inclusion, value: "unknown")
    assert reservation.errors.added?(:channel, :inclusion, value: "fax")
  end

  test "requires ends_at after starts_at on the same Tokyo business day" do
    reservation = build_reservation(ends_at: @starts_at)

    assert_not reservation.valid?
    assert reservation.errors.added?(:ends_at, :greater_than, value: @starts_at, count: @starts_at)

    reservation.ends_at = Time.zone.parse("2026-07-15 00:00")
    assert_not reservation.valid?
    assert reservation.errors.added?(:ends_at, :same_business_day)
  end

  test "validates party size against the resource capacity" do
    reservation = build_reservation(party_size: 5)

    assert_not reservation.valid?
    assert reservation.errors.added?(:party_size, :less_than_or_equal_to, count: 4)

    reservation.party_size = 0
    assert_not reservation.valid?
    assert reservation.errors.added?(:party_size, :greater_than_or_equal_to, value: 0, count: 1)
  end

  test "rejects inactive associations for new reservations" do
    @customer.update!(active: false)
    @resource.update!(active: false)
    reservation = build_reservation

    assert_not reservation.valid?
    assert reservation.errors.added?(:customer, :inactive)
    assert reservation.errors.added?(:reservation_resource, :inactive)
  end

  test "keeps an existing reservation valid after associations become inactive" do
    reservation = build_reservation
    reservation.save!
    @customer.update!(active: false)
    @resource.update!(active: false)

    reservation.memo = "到着時に受付"

    assert reservation.valid?
  end

  test "requires cancellation metadata only for canceled reservations" do
    account = Account.create!(email: "operator@example.com", password: "password123456")
    canceled = build_reservation(status: "canceled")

    assert_not canceled.valid?
    assert canceled.errors.added?(:canceled_at, :blank)
    assert canceled.errors.added?(:canceled_by, :blank)

    canceled.assign_attributes(canceled_at: Time.current, canceled_by: account, cancellation_reason: "お客様都合")
    assert canceled.valid?

    confirmed = build_reservation(canceled_at: Time.current, canceled_by: account, cancellation_reason: "誤入力")
    assert_not confirmed.valid?
    assert confirmed.errors.added?(:canceled_at, :present)
    assert confirmed.errors.added?(:canceled_by, :present)
    assert confirmed.errors.added?(:cancellation_reason, :present)
  end

  test "prevents overlapping blocking reservations on the same resource" do
    build_reservation.save!
    overlap = build_reservation(starts_at: @starts_at + 30.minutes, ends_at: @starts_at + 90.minutes)

    assert_not overlap.valid?
    assert overlap.errors.added?(:starts_at, :overlap)
  end

  test "allows adjacent, different-resource, and non-blocking reservations" do
    original = build_reservation
    original.save!

    adjacent = build_reservation(starts_at: original.ends_at, ends_at: original.ends_at + 1.hour)
    other_resource = ReservationResource.create!(name: "会議室B", kind: "room", capacity: 4)
    simultaneous = build_reservation(reservation_resource: other_resource)
    completed = build_reservation(status: "completed")

    assert adjacent.valid?
    assert simultaneous.valid?
    assert completed.valid?

    original.update!(status: "completed")
    assert build_reservation.valid?
  end

  test "prevents ordinary edits after reaching a terminal status" do
    reservation = build_reservation(status: "completed")
    reservation.save!

    reservation.memo = "書き換え"

    assert_not reservation.valid?
    assert reservation.errors.added?(:base, :terminal_record)
  end

  test "allows closing an ended reservation after resource capacity is reduced" do
    starts_at = Time.zone.yesterday.beginning_of_day + 10.hours
    reservation = build_reservation(
      starts_at: starts_at,
      ends_at: starts_at + 1.hour,
      party_size: 4
    )
    reservation.save!
    @resource.update!(capacity: 2)

    reservation.status = "completed"

    assert reservation.save
  end

  test "orders reservations by start time" do
    later = build_reservation(starts_at: @starts_at + 2.hours, ends_at: @starts_at + 3.hours, status: "completed")
    earlier = build_reservation(status: "completed")
    later.save!
    earlier.save!

    assert_equal [ earlier, later ], Reservation.chronological.to_a
  end

  private
    def build_reservation(attributes = {})
      Reservation.new({
        customer: @customer,
        reservation_resource: @resource,
        starts_at: @starts_at,
        ends_at: @starts_at + 1.hour,
        party_size: 2
      }.merge(attributes))
    end
end
