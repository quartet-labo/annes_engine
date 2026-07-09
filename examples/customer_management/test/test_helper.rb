ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  ANNE_ACCESS_ADMIN_RESOURCES = %w[customers persons organizations customer_contacts projects].freeze

  def grant_admin_access(account)
    role = anne_access_role("admin", "Admin")

    ANNE_ACCESS_ADMIN_RESOURCES.each do |resource|
      grant_permission(role, resource:, action: "manage")
    end

    AnneAccess::Assignment.find_or_create_by!(principal: account, role:)
  end

  def grant_viewer_access(account)
    role = anne_access_role("viewer", "Viewer")

    ANNE_ACCESS_ADMIN_RESOURCES.each do |resource|
      grant_permission(role, resource:, action: "read")
    end

    AnneAccess::Assignment.find_or_create_by!(principal: account, role:)
  end

  private
    def anne_access_role(key, name)
      AnneAccess::Role.find_or_create_by!(key:) do |role|
        role.name = name
        role.system = true
      end
    end

    def grant_permission(role, resource:, action:)
      permission = AnneAccess::Permission.find_or_create_by!(resource:, action:)
      AnneAccess::RolePermission.find_or_create_by!(role:, permission:)
    end
end
