AnneAuth.configure do |config|
  config.account_class_name = "CustomerAccount"
  config.account_session_class_name = "CustomerSession"
  config.account_identity_class_name = "CustomerAccountIdentity"
  config.account_verification_token_class_name = "CustomerAccountVerificationToken"
  config.account_password_reset_token_class_name = "CustomerAccountPasswordResetToken"
  config.account_invitation_token_class_name = "CustomerAccountInvitationToken"
  config.account_mailer_class_name = "CustomerAccountMailer"
  config.account_table_name = "customer_accounts"
  config.account_session_table_name = "customer_sessions"
  config.account_identity_table_name = "customer_account_identities"
  config.account_verification_token_table_name = "customer_account_verification_tokens"
  config.account_password_reset_token_table_name = "customer_account_password_reset_tokens"
  config.account_invitation_token_table_name = "customer_account_invitation_tokens"
  config.account_foreign_key = :customer_account_id
  config.account_session_cookie_name = :customer_session_id
  config.profile_complete = ->(account) { account.primary_customer.present? }
  config.after_account_login_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_email_verification_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_profile_completion_path = ->(controller, _account) { controller.main_app.root_path }
  config.account_profile_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_bootstrapped = ->(_account) {}
end
