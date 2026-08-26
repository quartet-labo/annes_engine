admin = Account.find_or_initialize_by(email: "admin@example.com")
admin.assign_attributes(
  name: "Sample Admin",
  role: "admin",
  password: "password-1234",
  password_confirmation: "password-1234"
)
admin.save!

admin_role = AnnesAccess::Role.find_or_create_by!(key: "admin") do |role|
  role.name = "Admin"
  role.system = true
end

viewer_role = AnnesAccess::Role.find_or_create_by!(key: "viewer") do |role|
  role.name = "Viewer"
  role.system = true
end

%w[customers persons organizations customer_contacts projects].each do |resource|
  manage_permission = AnnesAccess::Permission.find_or_create_by!(resource:, action: "manage")
  read_permission = AnnesAccess::Permission.find_or_create_by!(resource:, action: "read")

  AnnesAccess::RolePermission.find_or_create_by!(role: admin_role, permission: manage_permission)
  AnnesAccess::RolePermission.find_or_create_by!(role: viewer_role, permission: read_permission)
end

AnnesAccess::Assignment.find_or_create_by!(principal: admin, role: admin_role)

organization = Organization.find_or_create_by!(name: "サンプル株式会社") do |record|
  record.name_kana = "サンプルカブシキガイシャ"
  record.phone = "03-1234-0000"
  record.website = "https://example.com"
  record.memo = "社内管理用のサンプル法人顧客です。"
end

organization_customer = Customer.find_or_create_by!(customer_number: "C0001") do |record|
  record.kind = "organization"
  record.organization = organization
  record.status = "active"
  record.source = "紹介"
  record.memo = "法人として管理するサンプル顧客です。"
end

contact_person = Person.find_or_create_by!(email: "contact@example.com") do |record|
  record.name = "山田 太郎"
  record.name_kana = "ヤマダ タロウ"
  record.phone = "03-1234-5678"
  record.memo = "サンプル法人顧客の主担当者です。"
end

CustomerContact.find_or_create_by!(customer: organization_customer, person: contact_person) do |record|
  record.role = "primary"
  record.department = "総務部"
  record.title = "課長"
  record.email = contact_person.email
  record.phone = contact_person.phone
  record.primary = true
  record.memo = "法人顧客の主連絡先です。"
end

individual_person = Person.find_or_create_by!(email: "person@example.com") do |record|
  record.name = "佐藤 花子"
  record.name_kana = "サトウ ハナコ"
  record.phone = "090-1234-5678"
  record.memo = "個人顧客のサンプルです。"
end

individual_customer = Customer.find_or_create_by!(customer_number: "C0002") do |record|
  record.kind = "person"
  record.person = individual_person
  record.status = "active"
  record.source = "Web問い合わせ"
  record.memo = "個人として管理するサンプル顧客です。"
end

CustomerContact.find_or_create_by!(customer: individual_customer, person: individual_person) do |record|
  record.role = "primary"
  record.email = individual_person.email
  record.phone = individual_person.phone
  record.primary = true
  record.memo = "個人顧客本人の連絡先です。"
end

[
  [ "PRJ-001", "コーポレートサイト改修", "active", 2.weeks.from_now.to_date ],
  [ "PRJ-002", "問い合わせフォーム改善", "waiting", 1.month.from_now.to_date ],
  [ "PRJ-003", "保守契約更新", "lead", 2.months.from_now.to_date ]
].each do |project_number, name, status, due_on|
  Project.find_or_create_by!(project_number:) do |project|
    project.customer = organization_customer
    project.name = name
    project.status = status
    project.due_on = due_on
  end
end

Project.find_or_create_by!(project_number: "PRJ-004") do |project|
  project.customer = individual_customer
  project.name = "個人サイト相談"
  project.status = "lead"
  project.due_on = 3.weeks.from_now.to_date
end

puts "Sample users:"
puts "  admin@example.com / password-1234"
