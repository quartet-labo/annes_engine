AnnesAdmin.resource :reservation_resources, model: "ReservationResource" do
  label "予約対象"
  actions :index, :show, :new, :create, :edit, :update

  field :name, label: "名称", searchable: true, sortable: true
  field :kind,
    label: "種別",
    type: :enum,
    collection: -> { ReservationResource::KIND_LABELS },
    sortable: true
  field :capacity, label: "定員", type: :number, sortable: true
  field :active, label: "利用可", type: :boolean, sortable: true
  field :memo, label: "メモ", type: :text, searchable: true
  field :created_at, label: "登録日時", type: :datetime, permitted: false, sortable: true

  permitted_attributes :name, :kind, :capacity, :active, :memo
end
