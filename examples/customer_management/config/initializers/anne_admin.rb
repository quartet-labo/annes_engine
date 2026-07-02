AnneAdmin.configure do |config|
  config.site_name = "社内顧客管理"

  config.authenticate_with do |controller|
    admin_session = AnneAuth.configuration.admin_session_class.includes(:admin_user).find_by(id: controller.send(:cookies).signed[:admin_session_id])

    if admin_session
      AnneAuth::Current.session = admin_session
      true
    else
      controller.redirect_to(controller.main_app.admin_login_path, alert: "管理者ログインが必要です。")
      false
    end
  end

  config.current_user do |_controller|
    AnneAuth::Current.admin_user
  end

  config.authorize_with do |_context|
    true
  end

  config.resource :customers, model: "Customer", destroyable: true do
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

  config.resource :persons, model: "Person", destroyable: true do
    label "個人"
    field :name, label: "氏名", searchable: true, sortable: true
    field :name_kana, label: "氏名カナ", searchable: true, sortable: true
    field :email, label: "メールアドレス", searchable: true, sortable: true
    field :phone, label: "電話番号", searchable: true
    field :memo, label: "メモ", type: :text
    field :created_at, label: "登録日時", type: :datetime, permitted: false, sortable: true
    permitted_attributes :name, :name_kana, :email, :phone, :memo
  end

  config.resource :organizations, model: "Organization", destroyable: true do
    label "組織"
    field :name, label: "組織名", searchable: true, sortable: true
    field :name_kana, label: "組織名カナ", searchable: true, sortable: true
    field :phone, label: "代表電話", searchable: true
    field :website, label: "Webサイト", searchable: true
    field :memo, label: "メモ", type: :text
    field :created_at, label: "登録日時", type: :datetime, permitted: false, sortable: true
    permitted_attributes :name, :name_kana, :phone, :website, :memo
  end

  config.resource :customer_contacts, model: "CustomerContact", destroyable: true do
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

  config.resource :projects, model: "Project", destroyable: true do
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
end
