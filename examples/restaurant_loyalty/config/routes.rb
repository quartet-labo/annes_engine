Rails.application.routes.draw do
  root to: redirect("/customer")

  get "dashboard", to: redirect("/customer")

  scope :customer, as: :customer, module: :customers do
    root to: "dashboard#show"
    get "card", to: "cards#show", as: :card
    get "rewards", to: "rewards#index", as: :rewards
    post "rewards/:id/redeem", to: "rewards#create", as: :reward_redemption
    get "history", to: "history#index", as: :history
  end

  namespace :staff do
    root to: "members#index"
  end

  namespace :admin do
    get "home", to: redirect("/admin"), as: :root
    get "login", to: "sessions#new", as: :login
    post "session", to: "sessions#create", as: :session
    delete "logout", to: "sessions#destroy", as: :logout
  end

  get "auth/admin/login", to: redirect("/admin/login")
  get "auth/*path", to: redirect("/admin/login")

  mount AnneAdmin::Engine => "/admin", as: :anne_admin
end
