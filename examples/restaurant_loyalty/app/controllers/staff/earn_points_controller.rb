module Staff
  class EarnPointsController < BaseController
    before_action -> { authorize_loyalty!(:earn, :loyalty_points) }

    def new
      @member = AnnesLoyalty::LoyaltyMember.find_by(member_key: params[:member_key].to_s.strip)
      @amount_cents = params[:amount_cents].to_i if params[:amount_cents].present?
      @quote = AnnesLoyalty.quote_earn(member: @member, location: current_location, amount_cents: @amount_cents) if @member && @amount_cents.to_i.positive?
    end

    def create
      @member = find_member_by_key!(params[:member_key])
      @receipt = find_or_create_receipt!
      @entry = AnnesLoyalty.earn!(
        member: @member,
        location: current_location,
        amount_cents: @receipt.amount_cents,
        source: @receipt,
        actor: current_account,
        metadata: request_metadata
      )
      @balance = AnnesLoyalty.balance_for(member: @member)
      render :created, status: :created
    rescue ActiveRecord::RecordInvalid, AnnesLoyalty::Error => error
      @error = error_message(error)
      render :new, status: :unprocessable_content
    end

    private
      def find_or_create_receipt!
        receipt_number = params[:receipt_number].presence
        receipt = receipt_number ? Receipt.find_or_initialize_by(receipt_number:) : Receipt.new
        validate_existing_receipt!(receipt) if receipt.persisted?
        receipt.assign_attributes(
          customer: @member.owner,
          loyalty_location: current_location,
          amount_cents: params[:amount_cents],
          purchased_at: Time.current
        ) if receipt.new_record?
        receipt.save!
        receipt
      end

      def validate_existing_receipt!(receipt)
        return if receipt.customer == @member.owner && receipt.loyalty_location_id == current_location.id

        receipt.errors.add(:receipt_number, "has already been used for another member or location")
        raise ActiveRecord::RecordInvalid, receipt
      end

      def error_message(error)
        if error.respond_to?(:record) && error.record.errors.any?
          return error.record.errors.full_messages.to_sentence
        end

        error.message
      end
  end
end
