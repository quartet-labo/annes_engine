require "test_helper"

module Reservations
  class CreateTest < ActiveSupport::TestCase
    setup do
      @customer = Customer.create!(name: "作成テスト顧客")
      @resource = ReservationResource.create!(name: "作成テスト会議室", kind: "room", capacity: 4)
      @starts_at = Time.zone.parse("2026-07-14 10:00")
    end

    test "creates a confirmed reservation and returns it" do
      reservation = Create.new(valid_attributes).call

      assert_predicate reservation, :persisted?
      assert_equal "confirmed", reservation.status
      assert_match(/\AR-[0-9A-F]{8}\z/, reservation.reservation_number)
    end

    test "returns an invalid unsaved reservation for model validation errors" do
      reservation = Create.new(valid_attributes(ends_at: @starts_at)).call

      assert_not reservation.persisted?
      assert reservation.errors.added?(:ends_at, :greater_than, value: @starts_at, count: @starts_at)
    end

    test "returns an ordinary overlap as a model validation error" do
      Reservation.create!(valid_attributes)

      reservation = Create.new(valid_attributes(starts_at: @starts_at + 30.minutes, ends_at: @starts_at + 90.minutes)).call

      assert_not reservation.persisted?
      assert reservation.errors.added?(:starts_at, :overlap)
    end

    test "reassigns a colliding reservation number once" do
      Reservation.create!(valid_attributes(reservation_number: "R-DEADBEEF", status: "completed"))
      generated = %w[R-DEADBEEF R-CAFEBABE]

      reservation = Create.new(valid_attributes, number_generator: -> { generated.shift }).call

      assert_predicate reservation, :persisted?
      assert_equal "R-CAFEBABE", reservation.reservation_number
      assert_empty generated
    end

    test "converts the known exclusion constraint error" do
      error = ActiveRecord::StatementInvalid.new(
        'PG::ExclusionViolation: ERROR: conflicting key value violates exclusion constraint "reservations_no_blocking_time_overlap"'
      )
      failing_class = Class.new(Reservation) do
        define_method(:save) { raise error }
      end

      raised = assert_raises(ConflictError) do
        Create.new(valid_attributes, reservation_class: failing_class).call
      end

      assert_equal "予約対象の時間帯が既存予約と重複しています。", raised.message
    end

    test "reraises an unknown database error" do
      error = ActiveRecord::StatementInvalid.new("PG::CheckViolation: unknown_constraint")
      failing_class = Class.new(Reservation) do
        define_method(:save) { raise error }
      end

      raised = assert_raises(ActiveRecord::StatementInvalid) do
        Create.new(valid_attributes, reservation_class: failing_class).call
      end

      assert_same error, raised
    end

    private
      def valid_attributes(overrides = {})
        {
          customer: @customer,
          reservation_resource: @resource,
          starts_at: @starts_at,
          ends_at: @starts_at + 1.hour,
          party_size: 2,
          channel: "phone"
        }.merge(overrides)
      end
  end
end
