module Staff
  class BaseController < ApplicationController
    before_action :require_account_authentication
    helper_method :current_location

    rescue_from AnnesAccess::NotAuthorizedError do
      render plain: "Forbidden", status: :forbidden
    end

    private
      def authorize_loyalty!(action, resource)
        AnnesAccess.authorize!(current_account, action, resource)
      end

      def current_location
        @current_location ||= AnneLoyalty::LoyaltyLocation.active.order(:id).first ||
          raise(ActiveRecord::RecordNotFound, "No active loyalty location is available")
      end

      def find_member_by_key!(member_key)
        AnneLoyalty::LoyaltyMember.includes(:owner, :loyalty_program)
          .find_by!(member_key: member_key.to_s.strip)
      end

      def request_metadata
        {
          ip: request.remote_ip,
          user_agent: request.user_agent
        }
      end
  end
end
