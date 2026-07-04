AnneAdmin.resource :persons, model: "Person", destroyable: true do
  label "個人"
  field :name, label: "氏名", searchable: true, sortable: true
  field :name_kana, label: "氏名カナ", searchable: true, sortable: true
  field :email, label: "メールアドレス", searchable: true, sortable: true
  field :phone, label: "電話番号", searchable: true
  field :memo, label: "メモ", type: :text
  field :created_at, label: "登録日時", type: :datetime, permitted: false, sortable: true
  permitted_attributes :name, :name_kana, :email, :phone, :memo
end
