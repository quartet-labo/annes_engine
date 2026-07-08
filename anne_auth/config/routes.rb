AnneAuth::Engine.routes.draw do
  get "login", to: "accounts/sessions#new", as: :account_login
  resource :account_session, only: :create, controller: "accounts/sessions"
  match "auth/:provider/callback", to: "accounts/omniauth_callbacks#create", via: %i[get post], as: :account_omniauth_callback
  match "auth/failure", to: "accounts/omniauth_callbacks#failure", via: %i[get post]
  resource :account_password_reset, path: "password_reset", only: %i[new create edit update], controller: "accounts/password_resets"
  get "logout/confirm", to: "accounts/sessions#confirm", as: :account_logout_confirm
  delete "logout", to: "accounts/sessions#destroy", as: :account_logout
  get "signup", to: "accounts/registrations#new", as: :new_account_registration
  resource :account_registration, only: :create, controller: "accounts/registrations"
  get "email_verification/pending", to: "accounts/email_verifications#pending", as: :account_email_verification_pending
  get "email_verification", to: "accounts/email_verifications#show", as: :account_email_verification
  post "email_verification", to: "accounts/email_verifications#create"
  post "email_verification/verify", to: "accounts/email_verifications#verify", as: :account_email_verification_verify
  post "email_verification/resend", to: "accounts/email_verifications#resend", as: :account_email_verification_resend
end
