AnnesInquiry::Engine.routes.draw do
  root "admin/forms#index"
  namespace :admin do
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
