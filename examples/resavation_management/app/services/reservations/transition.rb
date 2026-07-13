module Reservations
  class Transition
    START_REQUIRED_EVENTS = %i[complete mark_no_show].freeze

    attr_reader :reservation

    def initialize(reservation, event:, actor:, lock_version:, cancellation_reason: nil)
      @reservation = reservation
      @event = event.to_s.to_sym
      @actor = actor
      @lock_version = lock_version
      @cancellation_reason = cancellation_reason
    end

    def call
      reservation.lock_version = lock_version
      fire_event!

      reservation
    rescue AASM::InvalidTransition, AASM::UndefinedEvent
      raise InvalidTransitionError, invalid_transition_message
    rescue ActiveRecord::StatementInvalid => error
      raise ConflictError, ConflictError::OVERLAP_MESSAGE if DatabaseConflict.overlap?(error)

      raise
    end

    private
      attr_reader :event, :actor, :lock_version, :cancellation_reason

      def fire_event!
        if event == :cancel
          reservation.aasm.fire!(event, actor, cancellation_reason, Time.current)
        else
          reservation.aasm.fire!(event)
        end
      end

      def invalid_transition_message
        if event.in?(START_REQUIRED_EVENTS) && reservation.status == "confirmed"
          return "開始時刻前の予約は完了または無断キャンセルにできません。"
        end

        "#{reservation.status}から#{event}へ状態を変更できません。"
      end
  end
end
