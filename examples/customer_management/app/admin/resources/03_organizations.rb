AnnesAdmin.resource :organizations, model: "Organization", destroyable: true do
  label "組織"
  field :name, label: "組織名", searchable: true, sortable: true
  field :name_kana, label: "組織名カナ", searchable: true, sortable: true
  field :phone, label: "代表電話", searchable: true
  field :website, label: "Webサイト", searchable: true
  field :memo, label: "メモ", type: :text
  field :created_at, label: "登録日時", type: :datetime, permitted: false, sortable: true
  permitted_attributes :name, :name_kana, :phone, :website, :memo
end
