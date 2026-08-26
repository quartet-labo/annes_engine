module Staff
  class RedemptionsController < BaseController
    before_action -> { authorize_loyalty!(:redeem, :loyalty_redemptions) }

    def new
    end

    def create
      @redemption = AnnesLoyalty.confirm_redemption!(
        token: params[:token],
        location: current_location,
        actor: current_account,
        metadata: request_metadata
      )
      @member = @redemption.loyalty_member
      @balance = AnnesLoyalty.balance_for(member: @member)
      render :created, status: :created
    rescue AnnesLoyalty::Error => error
      @error = error.message
      render :new, status: :unprocessable_content
    end
  end
end
