ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  ANNES_ACCESS_ADMIN_RESOURCES = %w[customers persons organizations customer_contacts projects].freeze

  def grant_admin_access(account)
    role = annes_access_role("admin", "Admin")

    ANNES_ACCESS_ADMIN_RESOURCES.each do |resource|
      grant_permission(role, resource:, action: "manage")
    end

    AnnesAccess::Assignment.find_or_create_by!(principal: account, role:)
  end

  def grant_viewer_access(account)
    role = annes_access_role("viewer", "Viewer")

    ANNES_ACCESS_ADMIN_RESOURCES.each do |resource|
      grant_permission(role, resource:, action: "read")
    end

    AnnesAccess::Assignment.find_or_create_by!(principal: account, role:)
  end

  private
    def annes_access_role(key, name)
      AnnesAccess::Role.find_or_create_by!(key:) do |role|
        role.name = name
        role.system = true
      end
    end

    def grant_permission(role, resource:, action:)
      permission = AnnesAccess::Permission.find_or_create_by!(resource:, action:)
      AnnesAccess::RolePermission.find_or_create_by!(role:, permission:)
    end
end
