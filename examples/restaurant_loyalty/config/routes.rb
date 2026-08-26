Rails.application.routes.draw do
  root to: redirect("/customer")

  get "dashboard", to: redirect("/customer")

  scope :customer, as: :customer, module: :customers do
    get "login", to: "sessions#new", as: :login
    post "session", to: "sessions#create", as: :session
    delete "logout", to: "sessions#destroy", as: :logout

    root to: "dashboard#show"
    get "card", to: "cards#show", as: :card
    get "rewards", to: "rewards#index", as: :rewards
    post "rewards/:id/redeem", to: "rewards#create", as: :reward_redemption
    get "history", to: "history#index", as: :history
  end

  namespace :staff do
    root to: "members#index"
    resources :members, only: %i[index show], param: :member_key
    get "earn", to: "earn_points#new", as: :earn_points
    post "earn", to: "earn_points#create"
    get "redemptions", to: "redemptions#new", as: :redemptions
    post "redemptions", to: "redemptions#create"
  end

  namespace :admin do
    get "home", to: redirect("/admin"), as: :root
    get "login", to: "sessions#new", as: :login
    post "session", to: "sessions#create", as: :session
    delete "logout", to: "sessions#destroy", as: :logout
  end

  get "auth/admin/login", to: redirect("/admin/login")
  get "auth/*path", to: redirect("/admin/login")

  mount AnnesAdmin::Engine => "/admin", as: :annes_admin
end
