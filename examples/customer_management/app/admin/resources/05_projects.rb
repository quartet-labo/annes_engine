AnnesAdmin.resource :projects, model: "Project", destroyable: true do
  label "案件"
  includes :customer
  field :customer_id,
    label: "顧客",
    type: :association,
    collection: -> { Customer.includes(:person, :organization).order(:customer_number) },
    display_with: ->(project) { project.customer&.display_name }
  field :project_number, label: "案件番号", searchable: true, sortable: true
  field :name, label: "案件名", searchable: true, sortable: true
  field :status, label: "ステータス", type: :enum, collection: -> { Project::STATUS_LABELS }, sortable: true
  field :due_on, label: "期限", type: :date, sortable: true
  field :memo, label: "メモ", type: :text
  permitted_attributes :customer_id, :project_number, :name, :status, :due_on, :memo
end
