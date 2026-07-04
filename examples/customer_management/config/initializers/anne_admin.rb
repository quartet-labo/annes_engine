AnneAdmin.configure do |config|
  config.site_name = "社内顧客管理"

  config.authenticate_with do |controller|
    admin_session = AnneAuth.configuration.admin_session_class.includes(:admin_user).find_by(id: controller.send(:cookies).signed[:admin_session_id])

    if admin_session
      AnneAuth::Current.session = admin_session
      true
    else
      controller.redirect_to(controller.main_app.admin_login_path, alert: "管理者ログインが必要です。")
      false
    end
  end

  config.current_user do |_controller|
    AnneAuth::Current.admin_user
  end

  config.authorize_with do |_context|
    true
  end
end
