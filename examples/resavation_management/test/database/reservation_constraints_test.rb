require "test_helper"

class ReservationConstraintsTest < ActiveSupport::TestCase
  setup do
    @customer = Customer.create!(name: "制約確認 顧客")
    @resource = ReservationResource.create!(name: "制約確認 会議室", kind: "room", capacity: 4)
    @starts_at = Time.zone.parse("2026-07-14 10:00")
  end

  test "database has the blocking overlap exclusion constraint" do
    constraint_names = ActiveRecord::Base.connection.select_values(<<~SQL)
      SELECT conname
      FROM pg_constraint
      WHERE conrelid = 'reservations'::regclass
    SQL

    assert_includes constraint_names, "reservations_no_blocking_time_overlap"
  end

  test "database rejects overlapping blocking reservations" do
    insert_reservation!(number: "R-DB000001")

    assert_raises(ActiveRecord::StatementInvalid) do
      insert_reservation!(
        number: "R-DB000002",
        starts_at: @starts_at + 30.minutes,
        ends_at: @starts_at + 90.minutes
      )
    end
  end

  test "database allows adjacent, different-resource, and canceled time ranges" do
    insert_reservation!(number: "R-DB000001")
    insert_reservation!(
      number: "R-DB000002",
      starts_at: @starts_at + 1.hour,
      ends_at: @starts_at + 2.hours
    )

    other_resource = ReservationResource.create!(name: "別会議室", kind: "room", capacity: 4)
    insert_reservation!(number: "R-DB000003", resource: other_resource)

    account = Account.create!(email: "cancel@example.com", password: "password123")
    insert_reservation!(
      number: "R-DB000004",
      status: "canceled",
      canceled_at: Time.current,
      canceled_by: account
    )

    assert_equal 4, Reservation.where(reservation_number: %w[R-DB000001 R-DB000002 R-DB000003 R-DB000004]).count
  end

  test "database enforces reservation value and cancellation checks" do
    assert_raises(ActiveRecord::StatementInvalid) do
      insert_reservation!(number: "R-DB000001", party_size: 0)
    end
  end

  private
    def insert_reservation!(number:, resource: @resource, starts_at: @starts_at, ends_at: @starts_at + 1.hour,
      status: "confirmed", party_size: 2, canceled_at: nil, canceled_by: nil)
      Reservation.insert!({
        reservation_number: number,
        customer_id: @customer.id,
        reservation_resource_id: resource.id,
        starts_at: starts_at,
        ends_at: ends_at,
        status: status,
        party_size: party_size,
        channel: "other",
        canceled_at: canceled_at,
        canceled_by_id: canceled_by&.id,
        lock_version: 0,
        created_at: Time.current,
        updated_at: Time.current
      })
    end
end
