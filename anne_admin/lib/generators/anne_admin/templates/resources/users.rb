AnneAdmin.resource :users, model: "User" do
  label "Users"
  field :email, searchable: true, sortable: true
  field :created_at, type: :datetime, permitted: false, sortable: true
  permitted_attributes :email
end
