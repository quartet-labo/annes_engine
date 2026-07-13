Rails.application.routes.draw do
  root to: redirect("/admin/reservations/schedule")

  get "dashboard", to: redirect("/admin/reservations/schedule")

  namespace :admin do
    get "home", to: redirect("/admin/reservations/schedule"), as: :root
    get "login", to: "sessions#new", as: :login
    post "session", to: "sessions#create", as: :session
    delete "logout", to: "sessions#destroy", as: :logout

    get "reservations/schedule", to: "reservations#schedule", as: :reservation_schedule

    resources :reservations, except: :destroy do
      member do
        get "cancel", action: :cancel_confirmation, as: :cancel_confirmation
        patch "cancel", action: :cancel, as: :cancel
        patch :confirm
        patch :complete
        patch :mark_no_show
      end
    end
  end

  get "auth/admin/login", to: redirect("/admin/login")
  get "auth/*path", to: redirect("/admin/login")

  mount AnneAdmin::Engine => "/admin", as: :anne_admin
end
