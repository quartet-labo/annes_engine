module Reservations
  class Transition
    TRANSITIONS = {
      "provisional" => {
        confirm: "confirmed",
        cancel: "canceled"
      },
      "confirmed" => {
        complete: "completed",
        cancel: "canceled",
        mark_no_show: "no_show"
      }
    }.freeze
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
      target_status = transition_target!
      validate_started!

      reservation.class.transaction do
        reservation.lock_version = lock_version
        reservation.status = target_status
        assign_cancellation_metadata if event == :cancel
        reservation.save!
      end

      reservation
    rescue ActiveRecord::StatementInvalid => error
      raise ConflictError, ConflictError::OVERLAP_MESSAGE if DatabaseConflict.overlap?(error)

      raise
    end

    private
      attr_reader :event, :actor, :lock_version, :cancellation_reason

      def transition_target!
        TRANSITIONS.dig(reservation.status, event) ||
          raise(
            InvalidTransitionError,
            "#{reservation.status}から#{event}へ状態を変更できません。"
          )
      end

      def validate_started!
        return unless event.in?(START_REQUIRED_EVENTS)
        return if reservation.starts_at.present? && reservation.starts_at <= Time.current

        raise InvalidTransitionError, "開始時刻前の予約は完了または無断キャンセルにできません。"
      end

      def assign_cancellation_metadata
        reservation.canceled_by = actor
        reservation.canceled_at = Time.current
        reservation.cancellation_reason = cancellation_reason
      end
  end
end
