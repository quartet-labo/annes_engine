seed_password = "password-1234"
role_permissions = {
  "admin" => {
    "loyalty_programs" => %w[manage],
    "loyalty_locations" => %w[manage],
    "loyalty_rewards" => %w[manage],
    "loyalty_members" => %w[read],
    "loyalty_points" => %w[earn adjust],
    "loyalty_redemptions" => %w[redeem]
  },
  "manager" => {
    "loyalty_programs" => %w[read update],
    "loyalty_locations" => %w[manage],
    "loyalty_rewards" => %w[manage],
    "loyalty_members" => %w[read],
    "loyalty_points" => %w[earn adjust],
    "loyalty_redemptions" => %w[redeem]
  },
  "staff" => {
    "loyalty_members" => %w[read],
    "loyalty_points" => %w[earn],
    "loyalty_redemptions" => %w[redeem]
  },
  "viewer" => {
    "loyalty_members" => %w[read]
  }
}

role_permissions.each do |role_key, resource_actions|
  account = Account.find_or_initialize_by(email: "#{role_key}@example.com")
  account.assign_attributes(password: seed_password, password_confirmation: seed_password)
  account.save!

  role = AnneAccess::Role.find_or_create_by!(key: role_key) do |record|
    record.name = role_key.humanize
    record.system = true
  end

  resource_actions.each do |resource, actions|
    actions.each do |action|
      permission = AnneAccess::Permission.find_or_create_by!(resource:, action:)
      AnneAccess::RolePermission.find_or_create_by!(role:, permission:)
    end
  end

  AnneAccess::Assignment.find_or_create_by!(principal: account, role:)
end

program = AnneLoyalty::LoyaltyProgram.find_or_initialize_by(code: "cafe-demo")
program.assign_attributes(
  name: "Cafe Demo",
  point_name: "pt",
  earn_unit_amount_cents: 100,
  earn_points_per_unit: 1,
  default_expiration_months: 12,
  active: true
)
program.save!

location = AnneLoyalty::LoyaltyLocation.find_or_initialize_by(loyalty_program: program, code: "ginza")
location.assign_attributes(name: "Ginza", time_zone: "Asia/Tokyo", active: true)
location.save!

rewards = {
  "coffee" => { name: "コーヒー無料", required_points: 20, valid_minutes: 10 },
  "dessert" => { name: "デザート無料", required_points: 40, valid_minutes: 10 }
}.to_h do |code, attributes|
  reward = AnneLoyalty::LoyaltyReward.find_or_initialize_by(loyalty_program: program, code:)
  reward.assign_attributes(attributes.merge(active: true))
  reward.save!
  [ code, reward ]
end

customers = {
  "C-DEMO-001" => { name: "山田 太郎", name_kana: "ヤマダ タロウ", email: "taro@example.com", phone: "090-1111-2222" },
  "C-DEMO-002" => { name: "佐藤 花子", name_kana: "サトウ ハナコ", email: "hanako@example.com", phone: "090-3333-4444" }
}.to_h do |customer_number, attributes|
  customer = Customer.find_or_initialize_by(customer_number:)
  customer.assign_attributes(attributes.merge(active: true))
  customer.save!
  member = AnneLoyalty.enroll!(program:, owner: customer, member_key: customer.customer_number)
  [ customer_number, { customer:, member: } ]
end

receipt = Receipt.find_or_initialize_by(receipt_number: "R-DEMO-001")
receipt.assign_attributes(
  customer: customers.fetch("C-DEMO-001").fetch(:customer),
  loyalty_location: location,
  amount_cents: 2_500,
  purchased_at: Time.zone.local(Date.current.year, Date.current.month, Date.current.day, 12)
)
receipt.save!

AnneLoyalty.earn!(
  member: customers.fetch("C-DEMO-001").fetch(:member),
  location:,
  amount_cents: receipt.amount_cents,
  source: receipt,
  occurred_at: receipt.purchased_at,
  actor: Account.find_by(email: "staff@example.com")
)

unless Rails.env.test?
  puts "Restaurant loyalty sample data is ready."
  puts "  admin@example.com / #{seed_password}"
  puts "  manager@example.com / #{seed_password}"
  puts "  staff@example.com / #{seed_password}"
  puts "  viewer@example.com / #{seed_password}"
  puts "  customer: C-DEMO-001"
  puts "  rewards: #{rewards.keys.join(", ")}"
end
