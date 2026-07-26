module Customers
  class BaseController < ApplicationController
    before_action :require_customer_authentication

    helper_method :current_customer, :loyalty_member, :customer_query

    private
      def current_customer
        @current_customer ||= Customer.active.find_by(id: session[:customer_id])
      end

      def require_customer_authentication
        return if current_customer

        redirect_to customer_login_path, alert: "顧客ログインが必要です。"
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
        {}
      end
  end
end
