module Customers
  class BaseController < ApplicationController
    helper_method :current_customer, :loyalty_member, :customer_query

    private
      def current_customer
        @current_customer ||= Customer.active.order(:id).find_by(id: params[:customer_id]) ||
          Customer.active.order(:id).first ||
          raise(ActiveRecord::RecordNotFound, "No active customer is available")
      end

      def loyalty_program
        @loyalty_program ||= AnneLoyalty::LoyaltyProgram.active.order(:id).first ||
          raise(ActiveRecord::RecordNotFound, "No active loyalty program is available")
      end

      def loyalty_member
        @loyalty_member ||= AnneLoyalty.enroll!(
          program: loyalty_program,
          owner: current_customer,
          member_key: current_customer.customer_number
        )
      end

      def customer_query
        { customer_id: current_customer.id }
      end
  end
end
