module AnnesLoyalty
  class PointLotConsumer
    def self.call(member:, points:, include_expired: false, preferred_lot_id: nil, preferred_expires_on: nil)
      new(member:, points:, include_expired:, preferred_lot_id:, preferred_expires_on:).call
    end

    def initialize(member:, points:, include_expired: false, preferred_lot_id: nil, preferred_expires_on: nil)
      @member = member
      @points = points.to_i
      @include_expired = include_expired
      @preferred_lot_id = preferred_lot_id
      @preferred_expires_on = preferred_expires_on
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
      attr_reader :member, :points, :include_expired, :preferred_lot_id, :preferred_expires_on

      def lots
        @lots ||= if include_expired
          all_lots = member.loyalty_point_lots.open.expiring_first.lock.to_a
          matched_lot, remaining = all_lots.partition { |lot| preferred_lot_id && lot.id.to_s == preferred_lot_id.to_s }
          matched_expiration, remaining = remaining.partition { |lot| preferred_expires_on && lot.expires_on == preferred_expires_on }
          same_expiration_state, other = remaining.partition do |lot|
            (lot.expires_on < Date.current) == (preferred_expires_on&.<(Date.current) || false)
          end
          matched_lot + matched_expiration + same_expiration_state + other
        else
          member.loyalty_point_lots.spendable.expiring_first.lock.to_a
        end
      end

      def available_points
        lots.sum(&:remaining_points)
      end
  end
end
