Rails.application.routes.draw do
  root "dummy#show"

  mount AnnesAdmin::Engine => "/admin", as: :annes_admin
end
