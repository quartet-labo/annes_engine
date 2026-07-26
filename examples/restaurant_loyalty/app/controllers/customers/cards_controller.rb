module Customers
  class CardsController < BaseController
    def show
      @balance = AnneLoyalty.balance_for(member: loyalty_member)
      @member_qr_payload = "member:#{loyalty_member.member_key}"
    end
  end
end
