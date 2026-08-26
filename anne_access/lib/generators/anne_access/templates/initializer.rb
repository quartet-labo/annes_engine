AnneAccess.configure do |config|
  # Principal classes are documented for host apps and future tooling. The
  # runtime authorization API accepts any persisted Active Record model assigned
  # through AnneAccess::Assignment.
  config.principal_class_names = ["Account"]

  # Override controller principal lookup when authentication and authorization
  # principals differ, such as AnnesAuth::Account sessions with host app User
  # permissions.
  # config.principal_resolver = ->(controller) { controller.send(:current_user) }

  # Keep empty by default for strict deny-by-default behavior. Add role keys such
  # as "admin" only when that role should bypass all permission checks.
  config.super_admin_role_keys = []

  # Leave nil to require explicit assignments. Set to "viewer" only when new
  # principals should receive read-only permissions implicitly.
  config.default_role_key = nil
end
