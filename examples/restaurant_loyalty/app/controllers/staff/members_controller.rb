module Staff
  class MembersController < BaseController
    before_action -> { authorize_loyalty!(:read, :loyalty_members) }

    def index
      @query = params[:q].to_s.strip
      @members = AnneLoyalty::LoyaltyMember.includes(:owner)
        .order(:member_key)
      @members = @members.where("member_key ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%") if @query.present?
    end

    def show
      @member = find_member_by_key!(params[:member_key])
      @balance = AnneLoyalty.balance_for(member: @member)
      @ledger_entries = @member.loyalty_ledger_entries.order(occurred_at: :desc, id: :desc).limit(10)
    end
  end
end
