module AnneLoyalty
  RedemptionIssue = Data.define(:redemption, :token)

  class RewardRedemptionIssuer
    def self.call(member:, reward:, actor: nil, issued_at: Time.current, metadata: {})
      new(member:, reward:, actor:, issued_at:, metadata:).call
    end

    def initialize(member:, reward:, actor:, issued_at:, metadata:)
      @member = member
      @reward = reward
      @actor = actor
      @issued_at = issued_at
      @metadata = metadata
    end

    def call
      LoyaltyMember.transaction do
        member.lock!
        reward.lock!
        validate_reward!
        validate_balance!

        token = RedemptionToken.generate
        redemption = member.loyalty_redemptions.create!(
          loyalty_reward: reward,
          status: "issued",
          token_digest: RedemptionToken.digest(token),
          issued_at:,
          expires_at: issued_at + reward.valid_minutes.minutes,
          metadata: AuditMetadata.build(actor:, metadata:)
        )

        RedemptionIssue.new(redemption:, token:)
      end
    end

    private
      attr_reader :member, :reward, :actor, :issued_at, :metadata

      def validate_reward!
        raise InactiveRewardError, "reward is inactive" unless reward.active?
        return if reward.loyalty_program_id == member.loyalty_program_id

        raise InactiveRewardError, "reward does not belong to the member program"
      end

      def validate_balance!
        balance = BalanceReader.call(member:)
        return if balance.cached_balance >= reward.required_points && balance.lot_balance >= reward.required_points

        raise InsufficientPointsError, "not enough points"
      end
  end
end
