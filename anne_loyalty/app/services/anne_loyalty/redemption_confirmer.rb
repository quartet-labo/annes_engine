module AnneLoyalty
  class RedemptionConfirmer
    def self.call(token:, location:, actor: nil, occurred_at: Time.current, metadata: {})
      new(token:, location:, actor:, occurred_at:, metadata:).call
    end

    def initialize(token:, location:, actor:, occurred_at:, metadata:)
      @token = token
      @location = location
      @actor = actor
      @occurred_at = occurred_at
      @metadata = metadata
    end

    def call
      redemption = find_redemption!
      expired = false

      result = LoyaltyRedemption.transaction do
        redemption.lock!
        member = redemption.loyalty_member
        member.lock!

        validate_redemption_status!(redemption)

        if redemption.token_expired?(at: occurred_at)
          redemption.update!(status: "expired") if redemption.issued?
          expired = true
          next redemption
        end

        validate_location!(redemption)
        consume_points!(member, redemption)
        ledger = create_ledger_entry!(member, redemption)
        mark_redeemed!(redemption, ledger)
        redemption
      end

      raise ExpiredRedemptionError, "redemption has expired" if expired

      result
    end

    private
      attr_reader :token, :location, :actor, :occurred_at, :metadata

      def find_redemption!
        LoyaltyRedemption.find_by(token_digest: RedemptionToken.digest(token)) ||
          raise(InvalidRedemptionTokenError, "redemption token is invalid")
      end

      def validate_redemption_status!(redemption)
        raise AlreadyRedeemedError, "redemption has already been redeemed" if redemption.redeemed?
        raise CanceledRedemptionError, "redemption has been canceled" if redemption.canceled?
        raise ExpiredRedemptionError, "redemption has expired" if redemption.expired?
      end

      def validate_location!(redemption)
        return if redemption.issued? && redemption.loyalty_reward.loyalty_program_id == location.loyalty_program_id

        raise InvalidRedemptionLocationError, "redemption cannot be used at this location"
      end

      def consume_points!(member, redemption)
        PointLotConsumer.call(member:, points: redemption.loyalty_reward.required_points)
        member.cached_balance -= redemption.loyalty_reward.required_points
        member.save!
      end

      def create_ledger_entry!(member, redemption)
        member.loyalty_ledger_entries.create!(
          loyalty_location: location,
          entry_type: "redeem",
          points_delta: -redemption.loyalty_reward.required_points,
          source_type: redemption.class.name,
          source_key: redemption.id.to_s,
          occurred_at:,
          metadata: AuditMetadata.build(
            actor:,
            metadata: metadata.merge(
              "loyalty_redemption_id" => redemption.id.to_s,
              "loyalty_reward_id" => redemption.loyalty_reward_id.to_s
            )
          )
        )
      end

      def mark_redeemed!(redemption, ledger)
        redemption.update!(
          status: "redeemed",
          redeemed_at: occurred_at,
          redeemed_loyalty_location: location,
          metadata: redemption.metadata.merge(
            AuditMetadata.build(
              actor:,
              metadata: metadata.merge("loyalty_ledger_entry_id" => ledger.id.to_s)
            )
          )
        )
      end
  end
end
