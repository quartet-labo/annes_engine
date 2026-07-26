AnneAdmin.resource :loyalty_locations, model: "AnneLoyalty::LoyaltyLocation" do
  label "店舗"
  actions :index, :show, :new, :create, :edit, :update

  includes :loyalty_program
  field :loyalty_program_id,
    label: "プログラム",
    type: :association,
    collection: -> { AnneLoyalty::LoyaltyProgram.order(:name) },
    display_with: ->(location) { location.loyalty_program&.name }
  field :code, label: "コード", searchable: true, sortable: true
  field :name, label: "店舗名", searchable: true, sortable: true
  field :time_zone, label: "タイムゾーン"
  field :active, label: "有効", type: :boolean, sortable: true
  field :created_at, label: "登録日時", type: :datetime, permitted: false, sortable: true

  permitted_attributes :loyalty_program_id, :code, :name, :time_zone, :active
end
