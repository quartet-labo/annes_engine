module Reservations
  class ConflictError < StandardError
    OVERLAP_MESSAGE = "予約対象の時間帯が既存予約と重複しています。"
    NUMBER_MESSAGE = "予約番号の採番が競合しました。もう一度お試しください。"
  end
end
