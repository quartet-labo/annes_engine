# Example AnnesAccess seed data. Adjust resources and assignments for the host app.
#
# Keep tenant, ownership, and membership scopes in host app controllers, query
# objects, model scopes, or services. This seed only creates the coarse RBAC
# matrix that those host-owned scopes can build on.
role_permissions = {
  "admin" => {
    name: "Admin",
    resources: {
      "customers" => %w[manage],
      "projects" => %w[manage]
    }
  },
  "viewer" => {
    name: "Viewer",
    resources: {
      "customers" => %w[read],
      "projects" => %w[read]
    }
  }
}

role_permissions.each do |role_key, definition|
  role = AnnesAccess::Role.find_or_initialize_by(key: role_key)
  role.update!(name: definition.fetch(:name), system: true)

  definition.fetch(:resources).each do |resource, actions|
    actions.each do |action|
      permission = AnnesAccess::Permission.find_or_create_by!(resource:, action:)
      AnnesAccess::RolePermission.find_or_create_by!(role:, permission:)
    end
  end
end
