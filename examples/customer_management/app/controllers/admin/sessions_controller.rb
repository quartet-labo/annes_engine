module Admin
  class SessionsController < AnneAuth::Admin::SessionsController
    def new
      redirect_to main_app.admin_root_path if admin_authenticated?
    end

    private
      def after_admin_authentication_url
        main_app.admin_root_path
      end
  end
end
