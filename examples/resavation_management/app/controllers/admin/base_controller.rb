module Admin
  class BaseController < AnneAdmin::ApplicationController
    include AnnesAccess::Authorization

    helper_method :can_access?

    rescue_from AnnesAccess::NotAuthorizedError, with: :render_forbidden
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    private
      def render_forbidden
        render plain: "Forbidden", status: :forbidden
      end

      def render_not_found
        render plain: "Not Found", status: :not_found
      end
  end
end
