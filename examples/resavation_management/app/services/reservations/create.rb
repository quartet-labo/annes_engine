require "securerandom"

module Reservations
  class Create
    MAX_NUMBER_RETRIES = 1
    DEFAULT_NUMBER_GENERATOR = -> { "R-#{SecureRandom.hex(4).upcase}" }

    attr_reader :reservation

    def initialize(attributes, reservation_class: Reservation, number_generator: DEFAULT_NUMBER_GENERATOR)
      @reservation = reservation_class.new(attributes)
      @number_generator = number_generator
    end

    def call
      number_retries = 0

      loop do
        assign_reservation_number
        saved = reservation.class.transaction { reservation.save }

        if !saved && reservation_number_taken?(reservation) && number_retries < MAX_NUMBER_RETRIES
          number_retries += 1
          prepare_number_retry
          next
        end

        return reservation
      rescue ActiveRecord::RecordNotUnique => error
        raise unless DatabaseConflict.reservation_number?(error)

        if number_retries < MAX_NUMBER_RETRIES
          number_retries += 1
          prepare_number_retry
          next
        end

        raise ConflictError, ConflictError::NUMBER_MESSAGE
      rescue ActiveRecord::StatementInvalid => error
        raise ConflictError, ConflictError::OVERLAP_MESSAGE if DatabaseConflict.overlap?(error)

        raise
      end
    end

    private
      attr_reader :number_generator

      def assign_reservation_number
        reservation.reservation_number = number_generator.call if reservation.reservation_number.blank?
      end

      def reservation_number_taken?(record)
        record.errors.details[:reservation_number].any? { |detail| detail[:error] == :taken }
      end

      def prepare_number_retry
        reservation.reservation_number = nil
        reservation.errors.clear
      end
  end
end
