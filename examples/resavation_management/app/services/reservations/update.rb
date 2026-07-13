module Reservations
  class Update
    attr_reader :reservation

    def initialize(reservation, attributes, lock_version:)
      @reservation = reservation
      @attributes = attributes
      @lock_version = lock_version
    end

    def call
      reservation.assign_attributes(attributes)
      reservation.lock_version = lock_version
      reservation.class.transaction { reservation.save }
      reservation
    rescue ActiveRecord::StatementInvalid => error
      raise ConflictError, ConflictError::OVERLAP_MESSAGE if DatabaseConflict.overlap?(error)

      raise
    end

    private
      attr_reader :attributes, :lock_version
  end
end
