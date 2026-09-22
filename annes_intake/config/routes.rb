AnnesIntake::Engine.routes.draw do
  root "admin/runs#index"
  get "flows/:key", to: "runs#new", as: :new_run
  post "flows/:key", to: "runs#create", as: :start_flow
  resources :runs, only: :show do
    member do
      post :resume
      get :review
      post :finalize
      post :cancel
    end
  end
  get "runs/:id/steps/:step_id", to: "runs#step", as: :step
  patch "runs/:id/steps/:step_id", to: "runs#save", as: :save_step
  get "runs/:id/steps/:step_id/attachments/:attachment_id", to: "runs#attachment", as: :flow_attachment
  namespace :admin do
    resources :runs, only: %i[index show] do
      get "steps/:step_id/attachments/:attachment_id", action: :attachment, on: :member, as: :attachment
    end
    resources :flows, only: %i[index create show update] do
      member do
        patch "versions/:version_id", action: :edit_version, as: :edit_version
        post "versions/:version_id/publish", action: :publish, as: :publish
        post "versions/:version_id/duplicate", action: :duplicate, as: :duplicate
        match "versions/:version_id/preview", action: :preview, via: %i[get post], as: :preview
      end
    end
    resources :forms, only: %i[index new create show update] do
      post :draft, on: :member
    end
    resources :versions, only: %i[show update destroy] do
      member do
        post :publish
        post :duplicate
        match :preview, via: %i[get post]
      end
      resources :fields, only: %i[new create]
    end
    resources :fields, only: %i[edit update destroy] do
      member do
        post "options", action: :add_option
        patch "options/:child_id", action: :update_option, as: :update_option
        delete "options/:child_id", action: :remove_option, as: :remove_option
        post "file_types", action: :add_file_type
        patch "file_types/:child_id", action: :update_file_type, as: :update_file_type
        delete "file_types/:child_id", action: :remove_file_type, as: :remove_file_type
      end
    end
  end
end
