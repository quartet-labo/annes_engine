require "test_helper"

module Reservations
  class UpdateTest < ActiveSupport::TestCase
    setup do
      @customer = Customer.create!(name: "更新テスト顧客")
      @resource = ReservationResource.create!(name: "更新テスト会議室", kind: "room", capacity: 4)
      @starts_at = Time.zone.parse("2026-07-14 10:00")
      @reservation = create_reservation!
    end

    test "updates an editable reservation with optimistic locking" do
      original_lock_version = @reservation.lock_version

      result = Update.new(
        @reservation,
        { memo: "窓側を希望", party_size: 3 },
        lock_version: original_lock_version
      ).call

      assert_predicate result, :persisted?
      assert_empty result.errors
      assert_equal [ "窓側を希望", 3 ], result.values_at(:memo, :party_size)
      assert_equal original_lock_version + 1, result.lock_version
    end

    test "returns validation errors without persisting invalid attributes" do
      result = Update.new(@reservation, { party_size: 5 }, lock_version: @reservation.lock_version).call

      assert result.errors.added?(:party_size, :less_than_or_equal_to, count: 4)
      assert_equal 2, Reservation.find(@reservation.id).party_size
    end

    test "does not update status outside the transition service" do
      result = Update.new(
        @reservation,
        { "status" => "completed", "memo" => "通常項目だけ更新" },
        lock_version: @reservation.lock_version
      ).call

      assert_empty result.errors
      assert_equal "confirmed", result.reload.status
      assert_equal "通常項目だけ更新", result.memo
    end

    test "rejects edits to terminal reservations" do
      completed = create_reservation!(
        starts_at: @starts_at + 2.hours,
        ends_at: @starts_at + 3.hours,
        status: "completed"
      )

      result = Update.new(completed, { memo: "変更不可" }, lock_version: completed.lock_version).call

      assert result.errors.added?(:base, :terminal_record)
      assert_nil Reservation.find(completed.id).memo
    end

    test "allows unrelated edits when existing associations became inactive" do
      @customer.update!(active: false)
      @resource.update!(active: false)

      result = Update.new(@reservation, { memo: "既存関連を維持" }, lock_version: @reservation.lock_version).call

      assert_empty result.errors
      assert_equal "既存関連を維持", result.reload.memo
    end

    test "raises stale object error without retrying" do
      stale = Reservation.find(@reservation.id)
      @reservation.update!(memo: "先行更新")

      assert_raises(ActiveRecord::StaleObjectError) do
        Update.new(stale, { memo: "古い更新" }, lock_version: stale.lock_version).call
      end

      assert_equal "先行更新", @reservation.reload.memo
    end

    test "converts the known exclusion constraint error" do
      error = ActiveRecord::StatementInvalid.new(
        'PG::ExclusionViolation: ERROR: conflicting key value violates exclusion constraint "reservations_no_blocking_time_overlap"'
      )
      @reservation.define_singleton_method(:save) { raise error }

      raised = assert_raises(ConflictError) do
        Update.new(@reservation, { memo: "競合" }, lock_version: @reservation.lock_version).call
      end

      assert_equal "予約対象の時間帯が既存予約と重複しています。", raised.message
    end

    private
      def create_reservation!(starts_at: @starts_at, ends_at: @starts_at + 1.hour, status: "confirmed")
        Reservation.create!(
          customer: @customer,
          reservation_resource: @resource,
          starts_at:,
          ends_at:,
          status:,
          party_size: 2,
          channel: "other"
        )
      end
  end
end
