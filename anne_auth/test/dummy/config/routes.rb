Rails.application.routes.draw do
  root "dummy#show"
  get "dashboard", to: "dummy#show", as: :dashboard
  get "admin", to: "dummy#show", as: :admin_root

  mount AnneAuth::Engine => "/auth"
end
