require "securerandom"

module AccessHelpers
  MASTER_RESOURCE_PERMISSIONS = {
    admin: {
      "customers" => %w[manage],
      "reservation_resources" => %w[manage]
    },
    operator: {
      "customers" => %w[read create update],
      "reservation_resources" => %w[read]
    },
    viewer: {
      "customers" => %w[read],
      "reservation_resources" => %w[read]
    }
  }.freeze

  def account_with_role(role_key)
    account = Account.create!(
      email: "#{role_key}-#{SecureRandom.hex(4)}@example.com",
      password: "password-1234",
      password_confirmation: "password-1234"
    )
    role = AnneAccess::Role.find_or_create_by!(key: role_key.to_s) do |record|
      record.name = role_key.to_s.humanize
      record.system = true
    end

    MASTER_RESOURCE_PERMISSIONS.fetch(role_key.to_sym).each do |resource, actions|
      actions.each do |action|
        permission = AnneAccess::Permission.find_or_create_by!(resource:, action:) do |record|
          record.key = "#{resource}.#{action}"
        end
        AnneAccess::RolePermission.find_or_create_by!(role:, permission:)
      end
    end

    AnneAccess::Assignment.find_or_create_by!(principal: account, role:)
    account
  end

  def sign_in_as_role(role_key)
    account = account_with_role(role_key)
    post admin_session_path, params: { email: account.email, password: "password-1234" }
    assert_redirected_to admin_root_path
    account
  end
end
