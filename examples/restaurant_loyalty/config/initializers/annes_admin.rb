Rails.application.config.to_prepare do
  AnnesAdmin::ApplicationController.include AnnesAuth::AccountAuthentication
end

AnnesAdmin.configure do |config|
  config.site_name = "飲食店ポイントカード demo"

  config.authenticate_with do |controller|
    if controller.send(:current_account_session)
      true
    else
      controller.redirect_to(controller.main_app.admin_login_path, alert: "ログインが必要です。")
      false
    end
  end

  config.current_user do |controller|
    controller.send(:current_account)
  end

  config.authorize_with do |context|
    AnnesAccess.can?(
      context[:user],
      context[:action],
      context[:resource].name,
      record: context[:record]
    )
  end
end
