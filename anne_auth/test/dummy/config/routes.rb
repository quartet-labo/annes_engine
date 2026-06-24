Rails.application.routes.draw do
  root "dummy#show"
  get "admin", to: "dummy#show", as: :admin_root

  mount AnneAuth::Engine => "/"
end
