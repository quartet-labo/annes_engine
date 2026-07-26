module AnneLoyalty
  class PointLotConsumer
    def self.call(member:, points:)
      new(member:, points:).call
    end

    def initialize(member:, points:)
      @member = member
      @points = points.to_i
    end

    def call
      raise InsufficientPointsError, "points must be positive" if points <= 0
      raise InsufficientPointsError, "not enough points" if available_points < points

      remaining_to_consume = points
      consumed_lots = []
      lots.each do |lot|
        break if remaining_to_consume.zero?

        consumed = [ lot.remaining_points, remaining_to_consume ].min
        consumed_lots << {
          "loyalty_point_lot_id" => lot.id.to_s,
          "points" => consumed,
          "expires_on" => lot.expires_on.iso8601
        }
        lot.remaining_points -= consumed
        lot.status = "consumed" if lot.remaining_points.zero?
        lot.save!
        remaining_to_consume -= consumed
      end
      consumed_lots
    end

    private
      attr_reader :member, :points

      def lots
        @lots ||= member.loyalty_point_lots.open.expiring_first.lock.to_a
      end

      def available_points
        lots.sum(&:remaining_points)
      end
  end
end
