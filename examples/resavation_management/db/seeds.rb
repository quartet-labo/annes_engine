seed_password = "password-1234"
role_permissions = {
  "admin" => {
    "customers" => %w[manage],
    "reservation_resources" => %w[manage],
    "reservations" => %w[manage confirm cancel complete no_show]
  },
  "operator" => {
    "customers" => %w[read create update],
    "reservation_resources" => %w[read],
    "reservations" => %w[manage confirm cancel complete no_show]
  },
  "viewer" => {
    "customers" => %w[read],
    "reservation_resources" => %w[read],
    "reservations" => %w[read]
  }
}
role_names = {
  "admin" => "Admin",
  "operator" => "Operator",
  "viewer" => "Viewer"
}
accounts = {}

role_permissions.each do |role_key, resource_actions|
  account = Account.find_or_initialize_by(email: "#{role_key}@example.com")
  account.assign_attributes(password: seed_password, password_confirmation: seed_password)
  account.save!

  role = AnnesAccess::Role.find_or_create_by!(key: role_key) do |record|
    record.name = role_names.fetch(role_key)
    record.system = true
  end

  resource_actions.each do |resource, actions|
    actions.each do |action|
      permission = AnnesAccess::Permission.find_or_create_by!(resource:, action:)
      AnnesAccess::RolePermission.find_or_create_by!(role:, permission:)
    end
  end

  AnnesAccess::Assignment.find_or_create_by!(principal: account, role:)
  accounts[role_key] = account
end

customers = {
  "C-DEMO-001" => {
    name: "山田 太郎",
    name_kana: "ヤマダ タロウ",
    email: "taro.yamada@example.com",
    phone: "090-1111-2222",
    memo: "会議室を定期利用するサンプル顧客",
    active: true
  },
  "C-DEMO-002" => {
    name: "佐藤 花子",
    name_kana: "サトウ ハナコ",
    email: "hanako.sato@example.com",
    phone: "090-3333-4444",
    memo: "貸出機材を利用するサンプル顧客",
    active: true
  },
  "C-DEMO-003" => {
    name: "鈴木 一郎",
    name_kana: "スズキ イチロウ",
    email: "ichiro.suzuki@example.com",
    phone: "03-5555-6666",
    memo: "取消済み予約を持つサンプル顧客",
    active: true
  },
  "C-DEMO-999" => {
    name: "利用停止 顧客",
    name_kana: "リヨウテイシ コキャク",
    email: "inactive.customer@example.com",
    phone: "03-9999-0000",
    memo: "新規予約では選択できないサンプル顧客",
    active: false
  }
}.to_h do |customer_number, attributes|
  customer = Customer.find_or_initialize_by(customer_number:)
  customer.assign_attributes(attributes)
  customer.save!
  [ customer_number, customer ]
end

resources = {
  "会議室A" => { kind: "room", capacity: 6, memo: "6名用会議室", active: true },
  "会議室B" => { kind: "room", capacity: 10, memo: "10名用会議室", active: true },
  "貸出機材" => { kind: "equipment", capacity: 1, memo: "プロジェクター一式", active: true },
  "利用停止対象" => { kind: "room", capacity: 4, memo: "メンテナンス中", active: false }
}.to_h do |name, attributes|
  resource = ReservationResource.find_or_initialize_by(name:)
  resource.assign_attributes(attributes)
  resource.save!
  [ name, resource ]
end

business_date = Date.current
zoned_time = lambda do |date, hour, minute = 0|
  Time.zone.local(date.year, date.month, date.day, hour, minute)
end

reservations = [
  {
    reservation_number: "R-DEMO-001",
    customer: customers.fetch("C-DEMO-001"),
    reservation_resource: resources.fetch("会議室A"),
    starts_at: zoned_time.call(business_date, 9),
    ends_at: zoned_time.call(business_date, 10),
    status: "confirmed",
    party_size: 4,
    channel: "phone",
    memo: "当日の予約確定サンプル"
  },
  {
    reservation_number: "R-DEMO-002",
    customer: customers.fetch("C-DEMO-002"),
    reservation_resource: resources.fetch("会議室A"),
    starts_at: zoned_time.call(business_date, 10),
    ends_at: zoned_time.call(business_date, 11),
    status: "confirmed",
    party_size: 2,
    channel: "web",
    memo: "直前の予約と連続するサンプル"
  },
  {
    reservation_number: "R-DEMO-003",
    customer: customers.fetch("C-DEMO-003"),
    reservation_resource: resources.fetch("会議室A"),
    starts_at: zoned_time.call(business_date, 9, 30),
    ends_at: zoned_time.call(business_date, 10, 30),
    status: "canceled",
    party_size: 3,
    channel: "email",
    memo: "取消済みの時間帯は再予約できる",
    cancellation_reason: "お客様都合",
    canceled_at: zoned_time.call(business_date, 8),
    canceled_by: accounts.fetch("operator")
  },
  {
    reservation_number: "R-DEMO-004",
    customer: customers.fetch("C-DEMO-001"),
    reservation_resource: resources.fetch("会議室B"),
    starts_at: zoned_time.call(business_date - 1.day, 13),
    ends_at: zoned_time.call(business_date - 1.day, 14),
    status: "completed",
    party_size: 6,
    channel: "counter",
    memo: "利用完了した過去予約"
  },
  {
    reservation_number: "R-DEMO-005",
    customer: customers.fetch("C-DEMO-002"),
    reservation_resource: resources.fetch("貸出機材"),
    starts_at: zoned_time.call(business_date - 1.day, 10),
    ends_at: zoned_time.call(business_date - 1.day, 11),
    status: "no_show",
    party_size: 1,
    channel: "phone",
    memo: "来訪がなかった過去予約"
  },
  {
    reservation_number: "R-DEMO-006",
    customer: customers.fetch("C-DEMO-003"),
    reservation_resource: resources.fetch("会議室B"),
    starts_at: zoned_time.call(business_date + 1.day, 13),
    ends_at: zoned_time.call(business_date + 1.day, 14),
    status: "provisional",
    party_size: 5,
    channel: "email",
    memo: "翌日の仮予約サンプル"
  }
]

Reservation.transaction do
  reservations.each do |attributes|
    reservation = Reservation.find_or_initialize_by(
      reservation_number: attributes.fetch(:reservation_number)
    )
    previous_status = reservation.status if reservation.persisted?
    reservation.assign_attributes(attributes.except(:reservation_number))

    next unless reservation.new_record? || reservation.has_changes_to_save?

    if Reservation::TERMINAL_STATUSES.include?(previous_status)
      reservation.destroy!
      Reservation.create!(attributes)
    else
      reservation.save!
    end
  end
end

puts "Reservation management sample data is ready."
puts "  admin@example.com / #{seed_password}"
puts "  operator@example.com / #{seed_password}"
puts "  viewer@example.com / #{seed_password}"
