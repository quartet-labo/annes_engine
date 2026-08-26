require "securerandom"

module AccessHelpers
  ROLE_PERMISSIONS = {
    admin: {
      "loyalty_programs" => %w[manage],
      "loyalty_locations" => %w[manage],
      "loyalty_rewards" => %w[manage],
      "loyalty_members" => %w[read],
      "loyalty_points" => %w[earn adjust],
      "loyalty_redemptions" => %w[redeem]
    },
    manager: {
      "loyalty_programs" => %w[read update],
      "loyalty_locations" => %w[manage],
      "loyalty_rewards" => %w[manage],
      "loyalty_members" => %w[read],
      "loyalty_points" => %w[earn adjust],
      "loyalty_redemptions" => %w[redeem]
    },
    staff: {
      "loyalty_members" => %w[read],
      "loyalty_points" => %w[earn],
      "loyalty_redemptions" => %w[redeem]
    },
    viewer: {
      "loyalty_members" => %w[read]
    }
  }.freeze

  def account_with_role(role_key)
    account = Account.create!(
      email: "#{role_key}-#{SecureRandom.hex(4)}@example.com",
      password: "password-1234",
      password_confirmation: "password-1234"
    )
    role = AnnesAccess::Role.find_or_create_by!(key: role_key.to_s) do |record|
      record.name = role_key.to_s.humanize
      record.system = true
    end

    ROLE_PERMISSIONS.fetch(role_key.to_sym).each do |resource, actions|
      actions.each do |action|
        permission = AnnesAccess::Permission.find_or_create_by!(resource:, action:) do |record|
          record.key = "#{resource}.#{action}"
        end
        AnnesAccess::RolePermission.find_or_create_by!(role:, permission:)
      end
    end

    AnnesAccess::Assignment.find_or_create_by!(principal: account, role:)
    account
  end

  def sign_in_as_role(role_key)
    account = account_with_role(role_key)
    post "/admin/session",
      params: { email: account.email, password: "password-1234" },
      headers: { "REMOTE_ADDR" => "192.0.2.#{SecureRandom.random_number(254) + 1}" }
    assert_redirected_to admin_root_path
    account
  end

  def sign_in_customer(customer, access_code: "123456")
    post "/customer/session",
      params: { customer_number: customer.customer_number, access_code: },
      headers: { "REMOTE_ADDR" => "198.51.100.#{SecureRandom.random_number(254) + 1}" }
    assert_redirected_to customer_root_path
    customer
  end
end
