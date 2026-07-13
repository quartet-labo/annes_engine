require "test_helper"

module Reservations
  class FilterTest < ActiveSupport::TestCase
    setup do
      @date = Date.new(2026, 7, 14)
      @customer = Customer.create!(
        name: "山田 100%_VIP",
        name_kana: "ヤマダ ビップ",
        email: "vip@example.com",
        phone: "03-1111-2222"
      )
      @other_customer = Customer.create!(name: "佐藤 花子", name_kana: "サトウ ハナコ")
      @resource = ReservationResource.create!(name: "会議室A", kind: "room", capacity: 6)
      @other_resource = ReservationResource.create!(name: "会議室B", kind: "room", capacity: 6)
      @actor = Account.create!(email: "filter@example.com", password: "password123456")
    end

    test "uses the Tokyo current date and returns reservations intersecting its boundaries" do
      travel_to Time.zone.parse("2026-07-14 12:00") do
        previous_day = create_reservation!(
          number: "R-PREVIOUS",
          starts_at: Time.zone.parse("2026-07-13 23:00"),
          ends_at: Time.zone.parse("2026-07-13 23:59"),
          status: "completed"
        )
        at_day_start = create_reservation!(
          number: "R-DAYSTART",
          starts_at: Time.zone.parse("2026-07-14 00:00"),
          ends_at: Time.zone.parse("2026-07-14 00:30"),
          status: "completed"
        )
        at_day_end = create_reservation!(
          number: "R-DAYEND00",
          starts_at: Time.zone.parse("2026-07-14 23:30"),
          ends_at: Time.zone.parse("2026-07-14 23:59"),
          status: "completed"
        )
        next_day = create_reservation!(
          number: "R-NEXTDAY",
          starts_at: Time.zone.parse("2026-07-15 00:00"),
          ends_at: Time.zone.parse("2026-07-15 00:30"),
          status: "completed"
        )

        filter = Filter.new

        assert_equal @date, filter.date
        assert_equal [ at_day_start, at_day_end ], filter.records.to_a
        assert_not_includes filter.records, previous_day
        assert_not_includes filter.records, next_day
      end
    end

    test "combines resource status and escaped customer keyword filters" do
      matching = create_reservation!(
        number: "R-MATCH001",
        starts_at: Time.zone.parse("2026-07-14 10:00"),
        ends_at: Time.zone.parse("2026-07-14 11:00"),
        status: "confirmed"
      )
      create_reservation!(
        number: "R-OTHERRES",
        customer: @customer,
        resource: @other_resource,
        starts_at: Time.zone.parse("2026-07-14 11:00"),
        ends_at: Time.zone.parse("2026-07-14 12:00"),
        status: "confirmed"
      )
      create_reservation!(
        number: "R-OTHERSTA",
        customer: @customer,
        starts_at: Time.zone.parse("2026-07-14 12:00"),
        ends_at: Time.zone.parse("2026-07-14 13:00"),
        status: "completed"
      )
      create_reservation!(
        number: "R-OTHERCUS",
        customer: @other_customer,
        starts_at: Time.zone.parse("2026-07-14 13:00"),
        ends_at: Time.zone.parse("2026-07-14 14:00"),
        status: "confirmed"
      )

      filter = Filter.new(
        date: "2026-07-14",
        reservation_resource_id: @resource.id.to_s,
        status: "confirmed",
        q: "100%_VIP"
      )

      assert_equal [ matching ], filter.records.to_a
      assert_predicate filter.records.first.association(:customer), :loaded?
      assert_predicate filter.records.first.association(:reservation_resource), :loaded?
    end

    test "searches reservation number and customer contact fields" do
      target = create_reservation!(
        number: "R-KEYWORD1",
        starts_at: Time.zone.parse("2026-07-14 10:00"),
        ends_at: Time.zone.parse("2026-07-14 11:00"),
        status: "completed"
      )
      create_reservation!(
        number: "R-UNRELATED",
        customer: @other_customer,
        starts_at: Time.zone.parse("2026-07-14 11:00"),
        ends_at: Time.zone.parse("2026-07-14 12:00"),
        status: "completed"
      )

      %w[KEYWORD ヤマダ vip@example.com 1111].each do |keyword|
        assert_equal [ target ], Filter.new(date: @date.to_s, q: keyword).records.to_a
      end
    end

    test "excludes canceled by default and includes it when requested explicitly or with all" do
      active = create_reservation!(
        number: "R-ACTIVE01",
        starts_at: Time.zone.parse("2026-07-14 10:00"),
        ends_at: Time.zone.parse("2026-07-14 11:00"),
        status: "completed"
      )
      canceled = create_reservation!(
        number: "R-CANCEL01",
        starts_at: Time.zone.parse("2026-07-14 11:00"),
        ends_at: Time.zone.parse("2026-07-14 12:00"),
        status: "canceled"
      )

      assert_equal [ active ], Filter.new(date: @date.to_s).records.to_a
      assert_equal [ canceled ], Filter.new(date: @date.to_s, status: "canceled").records.to_a
      assert_equal [ active, canceled ], Filter.new(date: @date.to_s, status: "all").records.to_a
    end

    test "normalizes invalid parameters" do
      travel_to Time.zone.parse("2026-07-14 12:00") do
        reservation = create_reservation!(
          number: "R-NORMAL01",
          starts_at: Time.zone.parse("2026-07-14 10:00"),
          ends_at: Time.zone.parse("2026-07-14 11:00"),
          status: "completed"
        )

        filter = Filter.new(
          date: "not-a-date",
          reservation_resource_id: "not-an-id",
          status: "unknown",
          page: "0",
          per_page: "0"
        )

        assert_equal @date, filter.date
        assert_equal 1, filter.page
        assert_equal 50, filter.per_page
        assert_equal [ reservation ], filter.records.to_a
      end
    end

    test "sorts stably and caps pagination at one hundred records" do
      now = Time.current
      rows = 102.times.map do |index|
        {
          reservation_number: format("R-PAGE%04d", index),
          customer_id: @customer.id,
          reservation_resource_id: @resource.id,
          starts_at: Time.zone.parse("2026-07-14 10:00"),
          ends_at: Time.zone.parse("2026-07-14 11:00"),
          status: "completed",
          party_size: 1,
          channel: "other",
          lock_version: 0,
          created_at: now,
          updated_at: now
        }
      end
      Reservation.insert_all!(rows)

      first_page = Filter.new(date: @date.to_s, per_page: "500")
      second_page = Filter.new(date: @date.to_s, page: "2", per_page: "100")

      assert_equal 100, first_page.per_page
      assert_equal 1, first_page.page
      assert_equal 102, first_page.total_count
      assert_equal 100, first_page.records.size
      assert_equal %w[R-PAGE0000 R-PAGE0001 R-PAGE0002], first_page.records.first(3).map(&:reservation_number)
      assert_equal 2, second_page.records.size
      assert_equal %w[R-PAGE0100 R-PAGE0101], second_page.records.map(&:reservation_number)
    end

    private
      def create_reservation!(number:, starts_at:, ends_at:, status:, customer: @customer, resource: @resource)
        Reservation.create!(
          reservation_number: number,
          customer:,
          reservation_resource: resource,
          starts_at:,
          ends_at:,
          status:,
          party_size: 1,
          channel: "other",
          canceled_at: status == "canceled" ? Time.current : nil,
          canceled_by: status == "canceled" ? @actor : nil
        )
      end
  end
end
