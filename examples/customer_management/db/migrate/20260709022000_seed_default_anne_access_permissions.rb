class SeedDefaultAnneAccessPermissions < ActiveRecord::Migration[8.1]
  RESOURCES = %w[customers persons organizations customer_contacts projects].freeze

  def up
    return unless anne_access_tables_exist?

    admin_role_id = ensure_role("admin", "Admin")
    viewer_role_id = ensure_role("viewer", "Viewer")

    RESOURCES.each do |resource|
      grant_permission(admin_role_id, resource, "manage")
      grant_permission(viewer_role_id, resource, "read")
    end

    assign_role_to_accounts(admin_role_id, "admin")
    assign_role_to_accounts(viewer_role_id, "viewer")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private
    def anne_access_tables_exist?
      %i[
        anne_access_roles
        anne_access_permissions
        anne_access_role_permissions
        anne_access_assignments
        accounts
      ].all? { |table_name| table_exists?(table_name) }
    end

    def ensure_role(key, name)
      now = quoted_now
      execute <<~SQL.squish
        INSERT INTO anne_access_roles (key, name, system, created_at, updated_at)
        VALUES (#{quote(key)}, #{quote(name)}, TRUE, #{now}, #{now})
        ON CONFLICT (key) DO NOTHING
      SQL

      select_value("SELECT id FROM anne_access_roles WHERE key = #{quote(key)}")
    end

    def grant_permission(role_id, resource, action)
      permission_id = ensure_permission(resource, action)
      now = quoted_now

      execute <<~SQL.squish
        INSERT INTO anne_access_role_permissions (role_id, permission_id, created_at, updated_at)
        VALUES (#{role_id}, #{permission_id}, #{now}, #{now})
        ON CONFLICT (role_id, permission_id) DO NOTHING
      SQL
    end

    def ensure_permission(resource, action)
      now = quoted_now
      key = "#{resource}.#{action}"

      execute <<~SQL.squish
        INSERT INTO anne_access_permissions (key, resource, action, created_at, updated_at)
        VALUES (#{quote(key)}, #{quote(resource)}, #{quote(action)}, #{now}, #{now})
        ON CONFLICT (resource, action) DO NOTHING
      SQL

      select_value(<<~SQL.squish)
        SELECT id
        FROM anne_access_permissions
        WHERE resource = #{quote(resource)}
          AND action = #{quote(action)}
      SQL
    end

    def assign_role_to_accounts(role_id, account_role)
      return unless column_exists?(:accounts, :role)

      now = quoted_now
      execute <<~SQL.squish
        INSERT INTO anne_access_assignments (principal_type, principal_id, role_id, created_at, updated_at)
        SELECT #{quote(account_principal_type)}, accounts.id, #{role_id}, #{now}, #{now}
        FROM accounts
        WHERE accounts.role = #{quote(account_role)}
        ON CONFLICT (principal_type, principal_id, role_id) DO NOTHING
      SQL
    end

    def account_principal_type
      if defined?(AnneAuth)
        AnneAuth.configuration.account_class.polymorphic_name
      else
        "Account"
      end
    end

    def quoted_now
      quote(Time.current)
    end
end
