AnnesAdmin::Engine.routes.draw do
  root "home#show"

  get "/:resource_name", to: "resources#index", as: :resource_index
  post "/:resource_name", to: "resources#create"
  get "/:resource_name/new", to: "resources#new", as: :new_resource
  match "/:resource_name/actions/:action_name", to: "resource_actions#collection", via: %i[post patch put delete], as: :resource_collection_action
  match "/:resource_name/:id/actions/:action_name", to: "resource_actions#member", via: %i[post patch put delete], as: :resource_member_action
  get "/:resource_name/:id", to: "resources#show", as: :resource_record
  get "/:resource_name/:id/edit", to: "resources#edit", as: :edit_resource_record
  patch "/:resource_name/:id", to: "resources#update"
  put "/:resource_name/:id", to: "resources#update"
  delete "/:resource_name/:id", to: "resources#destroy"
end
