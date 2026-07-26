module Customers
  class RewardsController < BaseController
    def index
      load_rewards
    end

    def create
      @reward = AnneLoyalty::LoyaltyReward.active
        .where(loyalty_program: loyalty_member.loyalty_program)
        .find(params[:id])
      @issue = AnneLoyalty.redeem_reward!(member: loyalty_member, reward: @reward)
      @redemption_qr_payload = "redemption:#{@issue.token}"
      load_rewards
      render :issued, status: :created
    rescue AnneLoyalty::Error => error
      @redemption_error = error.message
      load_rewards
      render :index, status: :unprocessable_content
    end

    private
      def load_rewards
        @balance = AnneLoyalty.balance_for(member: loyalty_member)
        @rewards = AnneLoyalty::LoyaltyReward.active
          .where(loyalty_program: loyalty_member.loyalty_program)
          .order(:required_points, :id)
      end
  end
end
