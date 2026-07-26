module Customers
  class DashboardController < BaseController
    def show
      @balance = AnneLoyalty.balance_for(member: loyalty_member)
      @next_reward = AnneLoyalty::LoyaltyReward.active
        .where(loyalty_program: loyalty_member.loyalty_program)
        .where("required_points > ?", @balance.cached_balance)
        .order(:required_points, :id)
        .first
      @affordable_rewards = AnneLoyalty::LoyaltyReward.active
        .where(loyalty_program: loyalty_member.loyalty_program)
        .affordable_for(loyalty_member)
        .order(:required_points, :id)
    end
  end
end
