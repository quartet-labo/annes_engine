AnneAdmin.resource :loyalty_rewards, model: "AnneLoyalty::LoyaltyReward" do
  label "特典"
  actions :index, :show, :new, :create, :edit, :update

  includes :loyalty_program
  field :loyalty_program_id,
    label: "プログラム",
    type: :association,
    collection: -> { AnneLoyalty::LoyaltyProgram.order(:name) },
    display_with: ->(reward) { reward.loyalty_program&.name }
  field :code, label: "コード", searchable: true, sortable: true
  field :name, label: "特典名", searchable: true, sortable: true
  field :required_points, label: "必要ポイント", type: :number, sortable: true
  field :valid_minutes, label: "有効分数", type: :number, sortable: true
  field :active, label: "有効", type: :boolean, sortable: true
  field :created_at, label: "登録日時", type: :datetime, permitted: false, sortable: true

  permitted_attributes :loyalty_program_id, :code, :name, :required_points, :valid_minutes, :active
end
