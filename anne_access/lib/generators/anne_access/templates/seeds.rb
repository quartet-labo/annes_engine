# Example AnneAccess seed data. Adjust resources and assignments for the host app.
admin = AnneAccess::Role.find_or_create_by!(key: "admin") do |role|
  role.name = "Admin"
  role.system = true
end

viewer = AnneAccess::Role.find_or_create_by!(key: "viewer") do |role|
  role.name = "Viewer"
  role.system = true
end

%w[customers projects].each do |resource|
  manage = AnneAccess::Permission.find_or_create_by!(resource:, action: "manage")
  read = AnneAccess::Permission.find_or_create_by!(resource:, action: "read")

  AnneAccess::RolePermission.find_or_create_by!(role: admin, permission: manage)
  AnneAccess::RolePermission.find_or_create_by!(role: viewer, permission: read)
end
