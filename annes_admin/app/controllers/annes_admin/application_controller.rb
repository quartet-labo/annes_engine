module AnnesAdmin
  class ApplicationController < ActionController::Base
    include AnnesAdmin::Authentication
    include AnnesAdmin::Authorization

    protect_from_forgery with: :exception
    layout "annes_admin/application"

    rescue_from AnnesAdmin::NotAuthorizedError, with: :render_forbidden

    private
      def render_forbidden
        render plain: "Forbidden", status: :forbidden
      end
  end
end
