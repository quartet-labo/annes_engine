module Customers
  class DashboardController < BaseController
    def show
      @balance = AnnesLoyalty.balance_for(member: loyalty_member)
      @next_reward = AnnesLoyalty::LoyaltyReward.active
        .where(loyalty_program: loyalty_member.loyalty_program)
        .where("required_points > ?", @balance.available_points)
        .order(:required_points, :id)
        .first
      @affordable_rewards = AnnesLoyalty::LoyaltyReward.active
        .where(loyalty_program: loyalty_member.loyalty_program)
        .affordable_for(loyalty_member)
        .order(:required_points, :id)
    end
  end
end
