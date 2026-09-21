AnnesInquiry::Engine.routes.draw do
  root "admin/forms#index"
  get "flows/:key", to: "flow_runs#new", as: :new_flow_run
  post "flows/:key", to: "flow_runs#create", as: :start_flow
  resources :flow_runs, only: :show do
    member do
      post :resume
      get :review
      post :finalize
      post :cancel
    end
  end
  get "flow_runs/:id/steps/:step_id", to: "flow_runs#step", as: :flow_step
  patch "flow_runs/:id/steps/:step_id", to: "flow_runs#save", as: :save_flow_step
  get "flow_runs/:id/steps/:step_id/attachments/:attachment_id", to: "flow_runs#attachment", as: :flow_attachment
  namespace :admin do
    resources :flows, only: %i[index create show update] do
      member do
        patch "versions/:version_id", action: :edit_version, as: :edit_version
        post "versions/:version_id/publish", action: :publish, as: :publish
        post "versions/:version_id/duplicate", action: :duplicate, as: :duplicate
        match "versions/:version_id/preview", action: :preview, via: %i[get post], as: :preview
      end
      resources :runs, controller: :flow_runs, as: :runs, only: %i[index show] do
        get "steps/:step_id/attachments/:attachment_id", action: :attachment, on: :member, as: :attachment
      end
    end
    resources :submissions, only: %i[index show] do
      resources :attachments, only: :show
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
  get "forms/:key", to: "public_submissions#show", as: :form
  post "forms/:key", to: "public_submissions#create"
  get "complete/:receipt_id", to: "public_submissions#completion", as: :completion
end
