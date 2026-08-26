AnnesAdmin.resource :customer_contacts, model: "CustomerContact", destroyable: true do
  label "顧客連絡先"
  includes :customer, :person
  field :customer_id,
    label: "顧客",
    type: :association,
    collection: -> { Customer.includes(:person, :organization).order(:customer_number) },
    display_with: ->(contact) { contact.customer&.display_name }
  field :person_id,
    label: "個人",
    type: :association,
    collection: -> { Person.order(:name) },
    display_with: ->(contact) { contact.person&.display_name }
  field :role, label: "役割", type: :enum, collection: -> { CustomerContact::ROLE_LABELS }, sortable: true
  field :department, label: "部署", searchable: true
  field :title, label: "役職", searchable: true
  field :email, label: "メールアドレス", searchable: true, sortable: true
  field :phone, label: "電話番号", searchable: true
  field :primary, label: "主連絡先", type: :boolean, sortable: true
  field :memo, label: "メモ", type: :text
  field :created_at, label: "登録日時", type: :datetime, permitted: false, sortable: true
  permitted_attributes :customer_id, :person_id, :role, :department, :title, :email, :phone, :primary, :memo
end
