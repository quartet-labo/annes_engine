Rails.application.routes.draw do
  root "dummy#show"

  mount AnneAdmin::Engine => "/admin", as: :anne_admin
end
