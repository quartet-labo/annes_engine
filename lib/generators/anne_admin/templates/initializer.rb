require "anne_admin"

AnneAdmin.configure do |config|
  config.site_name = "Admin"

  config.authenticate_with do |controller|
    # Replace this with your application's admin authentication.
    controller.redirect_to(controller.main_app.root_path, alert: "Admin authentication is required.")
    false
  end

  config.current_user do |_controller|
    nil
  end

  # Example:
  # config.resource :users, model: "User" do
  #   label "Users"
  #   field :email, searchable: true, sortable: true
  #   field :created_at, type: :datetime, permitted: false, sortable: true
  #   permitted_attributes :email
  # end
end
