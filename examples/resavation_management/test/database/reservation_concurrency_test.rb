require "test_helper"

class ReservationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  class Barrier
    attr_reader :arrivals

    def initialize(parties)
      @parties = parties
      @arrivals = 0
      @mutex = Mutex.new
      @condition = ConditionVariable.new
    end

    def wait
      @mutex.synchronize do
        @arrivals += 1
        if @arrivals == @parties
          @condition.broadcast
        else
          @condition.wait(@mutex, 5)
          raise "barrier timed out" unless @arrivals == @parties
        end
      end
    end
  end

  setup do
    Reservation.delete_all
    Customer.delete_all
    ReservationResource.delete_all

    @customer = Customer.create!(name: "並行テスト顧客")
    @resource = ReservationResource.create!(name: "並行テスト会議室", kind: "room", capacity: 4)
    @starts_at = Time.zone.parse("2026-07-14 10:00")
  end

  teardown do
    Reservation.delete_all
    Customer.delete_all
    ReservationResource.delete_all
  end

  test "two connections racing for the same time slot yield one success and one conflict" do
    barrier = Barrier.new(2)
    results = Queue.new
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      sql = payload[:sql].to_s
      overlap_validation = sql.include?('SELECT 1 AS one FROM "reservations"') &&
        sql.include?("starts_at") &&
        sql.include?("ends_at")
      barrier.wait if overlap_validation
    end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      threads = 2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            reservation = Reservations::Create.new(valid_attributes).call
            results << reservation
          rescue StandardError => error
            results << error
          end
        end
      end
      threads.each(&:join)
    end

    outcomes = 2.times.map { results.pop }
    assert_equal 2, barrier.arrivals
    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(Reservation) && outcome.persisted? }
    assert_equal 1, outcomes.count { |outcome| outcome.is_a?(Reservations::ConflictError) }
    assert_equal 1, Reservation.count
  end

  private
    def valid_attributes
      {
        customer: @customer,
        reservation_resource: @resource,
        starts_at: @starts_at,
        ends_at: @starts_at + 1.hour,
        party_size: 2,
        channel: "other"
      }
    end
end
