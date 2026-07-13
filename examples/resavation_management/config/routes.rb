Rails.application.routes.draw do
  root to: redirect("/admin")

  get "dashboard", to: redirect("/admin")

  get "admin/home", to: redirect("/admin/"), as: :admin_root
  get "admin/login", to: "admin/sessions#new", as: :admin_login
  post "admin/session", to: "admin/sessions#create", as: :admin_session
  delete "admin/logout", to: "admin/sessions#destroy", as: :admin_logout

  get "auth/admin/login", to: redirect("/admin/login")
  get "auth/*path", to: redirect("/admin/login")

  mount AnneAdmin::Engine => "/admin", as: :anne_admin
end
