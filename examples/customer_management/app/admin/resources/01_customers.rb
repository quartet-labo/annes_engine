AnnesAdmin.resource :customers, model: "Customer", destroyable: true do
  label "顧客"
  includes :person, :organization
  field :customer_number, label: "顧客番号", searchable: true, sortable: true
  field :kind, label: "種別", type: :enum, collection: -> { Customer::KIND_LABELS }, sortable: true
  field :person_id,
    label: "個人",
    type: :association,
    collection: -> { Person.order(:name) },
    display_with: ->(customer) { customer.person&.display_name }
  field :organization_id,
    label: "組織",
    type: :association,
    collection: -> { Organization.order(:name) },
    display_with: ->(customer) { customer.organization&.display_name }
  field :status, label: "ステータス", type: :enum, collection: -> { Customer::STATUS_LABELS }, sortable: true
  field :source, label: "流入経路", searchable: true
  field :memo, label: "メモ", type: :text
  field :created_at, label: "登録日時", type: :datetime, permitted: false, sortable: true
  permitted_attributes :customer_number, :kind, :person_id, :organization_id, :status, :source, :memo
end
