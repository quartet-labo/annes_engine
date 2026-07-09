AnneAccess.configure do |config|
  # Principal classes are documented for host apps and future tooling. The
  # runtime authorization API accepts any persisted Active Record model assigned
  # through AnneAccess::Assignment.
  config.principal_class_names = ["Account"]

  # Keep empty by default for strict deny-by-default behavior. Add role keys such
  # as "admin" only when that role should bypass all permission checks.
  config.super_admin_role_keys = []

  # Leave nil to require explicit assignments. Set to "viewer" only when new
  # principals should receive read-only permissions implicitly.
  config.default_role_key = nil
end
