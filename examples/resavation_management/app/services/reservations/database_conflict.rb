module Reservations
  module DatabaseConflict
    OVERLAP_CONSTRAINT = "reservations_no_blocking_time_overlap"
    NUMBER_INDEX = "index_reservations_on_reservation_number"

    module_function

    def overlap?(error)
      error.message.include?(OVERLAP_CONSTRAINT)
    end

    def reservation_number?(error)
      error.message.include?(NUMBER_INDEX)
    end
  end
end
