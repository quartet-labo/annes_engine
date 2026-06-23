module AnneAdmin
  class ApplicationController < ActionController::Base
    include AnneAdmin::Authentication
    include AnneAdmin::Authorization

    protect_from_forgery with: :exception
    layout "anne_admin/application"

    rescue_from AnneAdmin::NotAuthorizedError, with: :render_forbidden

    private
      def render_forbidden
        render plain: "Forbidden", status: :forbidden
      end
  end
end
