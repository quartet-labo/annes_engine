module Staff
  class EarnPointsController < BaseController
    before_action -> { authorize_loyalty!(:earn, :loyalty_points) }

    def new
      @member = AnneLoyalty::LoyaltyMember.find_by(member_key: params[:member_key].to_s.strip)
      @amount_cents = params[:amount_cents].to_i if params[:amount_cents].present?
      @quote = AnneLoyalty.quote_earn(member: @member, location: current_location, amount_cents: @amount_cents) if @member && @amount_cents.to_i.positive?
    end

    def create
      @member = find_member_by_key!(params[:member_key])
      @receipt = find_or_create_receipt!
      @entry = AnneLoyalty.earn!(
        member: @member,
        location: current_location,
        amount_cents: @receipt.amount_cents,
        source: @receipt,
        actor: current_account,
        metadata: request_metadata
      )
      @balance = AnneLoyalty.balance_for(member: @member)
      render :created, status: :created
    rescue ActiveRecord::RecordInvalid, AnneLoyalty::Error => error
      @error = error.message
      render :new, status: :unprocessable_content
    end

    private
      def find_or_create_receipt!
        receipt_number = params[:receipt_number].presence
        receipt = receipt_number ? Receipt.find_or_initialize_by(receipt_number:) : Receipt.new
        receipt.assign_attributes(
          customer: @member.owner,
          loyalty_location: current_location,
          amount_cents: params[:amount_cents],
          purchased_at: Time.current
        ) if receipt.new_record?
        receipt.save!
        receipt
      end
  end
end
