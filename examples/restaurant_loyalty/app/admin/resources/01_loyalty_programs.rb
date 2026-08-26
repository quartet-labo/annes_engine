AnnesAdmin.resource :loyalty_programs, model: "AnneLoyalty::LoyaltyProgram" do
  label "ポイントプログラム"
  actions :index, :show, :new, :create, :edit, :update

  field :code, label: "コード", searchable: true, sortable: true
  field :name, label: "名称", searchable: true, sortable: true
  field :point_name, label: "ポイント名"
  field :earn_unit_amount_cents, label: "付与単位", type: :number, sortable: true
  field :earn_points_per_unit, label: "単位ポイント", type: :number, sortable: true
  field :default_expiration_months, label: "有効月数", type: :number, sortable: true
  field :active, label: "有効", type: :boolean, sortable: true
  field :created_at, label: "登録日時", type: :datetime, permitted: false, sortable: true

  permitted_attributes :code, :name, :point_name, :earn_unit_amount_cents, :earn_points_per_unit, :default_expiration_months, :active
end
