module AnneAdmin
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_anne_admin!
      helper_method :anne_admin_current_user
    end

    private
      def authenticate_anne_admin!
        AnneAdmin.configuration.authenticate!(self)
      end

      def anne_admin_current_user
        @anne_admin_current_user ||= AnneAdmin.configuration.current_user_for(self)
      end
  end
end
