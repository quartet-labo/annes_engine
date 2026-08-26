module AnnesAdmin
  module Authentication
    extend ActiveSupport::Concern

    included do
      before_action :authenticate_annes_admin!
      helper_method :annes_admin_current_user
    end

    private
      def authenticate_annes_admin!
        AnnesAdmin.configuration.authenticate!(self)
      end

      def annes_admin_current_user
        @annes_admin_current_user ||= AnnesAdmin.configuration.current_user_for(self)
      end
  end
end
