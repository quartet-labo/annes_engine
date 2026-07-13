require "test_helper"

module Reservations
  class TransitionTest < ActiveSupport::TestCase
    EVENTS = %i[confirm cancel complete mark_no_show].freeze
    ALLOWED_TRANSITIONS = {
      provisional: { confirm: "confirmed", cancel: "canceled" },
      confirmed: { complete: "completed", cancel: "canceled", mark_no_show: "no_show" }
    }.freeze

    setup do
      @customer = Customer.create!(name: "遷移テスト顧客")
      @resource = ReservationResource.create!(name: "遷移テスト会議室", kind: "room", capacity: 4)
      @actor = Account.create!(email: "transition@example.com", password: "password123456")
      @starts_at = Time.zone.parse("2026-07-14 10:00")
      @reservation_sequence = 0
    end

    test "performs every allowed state transition" do
      travel_to Time.zone.parse("2026-07-14 12:00") do
        ALLOWED_TRANSITIONS.each do |from_status, transitions|
          transitions.each do |event, expected_status|
            reservation = create_reservation!(status: from_status.to_s)

            result = Transition.new(
              reservation,
              event:,
              actor: @actor,
              lock_version: reservation.lock_version,
              cancellation_reason: event == :cancel ? "お客様都合" : nil
            ).call

            assert_equal expected_status, result.status, "expected #{from_status} -> #{event}"
          end
        end
      end
    end

    test "rejects every transition not present in the state table" do
      travel_to Time.zone.parse("2026-07-14 12:00") do
        Reservation::STATUSES.each do |status|
          EVENTS.each do |event|
            next if ALLOWED_TRANSITIONS.fetch(status.to_sym, {}).key?(event)

            reservation = create_reservation!(status:)

            assert_raises(InvalidTransitionError, "expected #{status} -> #{event} to fail") do
              Transition.new(
                reservation,
                event:,
                actor: @actor,
                lock_version: reservation.lock_version
              ).call
            end
            assert_equal status, reservation.reload.status
          end
        end
      end
    end

    test "stores cancellation metadata atomically" do
      reservation = create_reservation!(status: "confirmed")
      canceled_at = Time.zone.parse("2026-07-14 09:00")

      travel_to canceled_at do
        Transition.new(
          reservation,
          event: :cancel,
          actor: @actor,
          lock_version: reservation.lock_version,
          cancellation_reason: "体調不良"
        ).call
      end

      reservation.reload
      assert_equal "canceled", reservation.status
      assert_equal @actor, reservation.canceled_by
      assert_equal canceled_at, reservation.canceled_at
      assert_equal "体調不良", reservation.cancellation_reason
    end

    test "rejects complete and no show before the reservation starts" do
      travel_to Time.zone.parse("2026-07-14 09:00") do
        %i[complete mark_no_show].each do |event|
          reservation = create_reservation!(status: "confirmed")

          error = assert_raises(InvalidTransitionError) do
            Transition.new(
              reservation,
              event:,
              actor: @actor,
              lock_version: reservation.lock_version
            ).call
          end

          assert_equal "開始時刻前の予約は完了または無断キャンセルにできません。", error.message
          assert_equal "confirmed", reservation.reload.status
        end
      end
    end

    test "raises stale object error without retrying a transition" do
      reservation = create_reservation!(status: "provisional")
      stale = Reservation.find(reservation.id)
      reservation.update!(memo: "先行更新")

      assert_raises(ActiveRecord::StaleObjectError) do
        Transition.new(
          stale,
          event: :confirm,
          actor: @actor,
          lock_version: stale.lock_version
        ).call
      end

      assert_equal "provisional", reservation.reload.status
      assert_equal "先行更新", reservation.memo
    end

    test "rejects unknown events" do
      reservation = create_reservation!(status: "confirmed")

      assert_raises(InvalidTransitionError) do
        Transition.new(
          reservation,
          event: :reopen,
          actor: @actor,
          lock_version: reservation.lock_version
        ).call
      end
    end

    private
      def create_reservation!(status:)
        canceled = status == "canceled"
        starts_at = @starts_at + (@reservation_sequence * 5.minutes)
        @reservation_sequence += 1
        Reservation.create!(
          customer: @customer,
          reservation_resource: @resource,
          starts_at:,
          ends_at: starts_at + 1.minute,
          status:,
          party_size: 1,
          channel: "other",
          canceled_at: canceled ? Time.current : nil,
          canceled_by: canceled ? @actor : nil
        )
      end
  end
end
