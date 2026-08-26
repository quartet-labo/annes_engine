require "test_helper"
require_relative "../../db/migrate/20260826001000_rename_anne_access_tables_to_annes_access"

class AnnesAccess::LegacyRbacSchemaRenameMigrationTest < AnnesAccess::TestCase
  OLD_TABLES = %i[
    anne_access_assignments
    anne_access_role_permissions
    anne_access_permissions
    anne_access_roles
  ].freeze
  NEW_TABLES = %i[
    annes_access_assignments
    annes_access_role_permissions
    annes_access_permissions
    annes_access_roles
  ].freeze

  test "preserves RBAC rows, indexes, and foreign keys when renaming legacy tables" do
    create_legacy_schema
    connection = ActiveRecord::Base.connection
    connection.execute <<~SQL
      INSERT INTO anne_access_roles (key, name, system, created_at, updated_at)
      VALUES ('admin', 'Administrator', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    connection.execute <<~SQL
      INSERT INTO anne_access_permissions (key, resource, action, created_at, updated_at)
      VALUES ('projects.read', 'projects', 'read', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    connection.execute <<~SQL
      INSERT INTO anne_access_role_permissions (role_id, permission_id, created_at, updated_at)
      VALUES (1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
    connection.execute <<~SQL
      INSERT INTO anne_access_assignments (principal_type, principal_id, role_id, created_at, updated_at)
      VALUES ('Account', 1, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    RenameAnneAccessTablesToAnnesAccess.migrate(:up)

    assert_empty OLD_TABLES.select { |table| connection.data_source_exists?(table) }
    assert_equal [ "admin" ], connection.select_values("SELECT key FROM annes_access_roles")
    assert_equal [ "projects.read" ], connection.select_values("SELECT key FROM annes_access_permissions")
    assert_equal [ "Account" ], connection.select_values("SELECT principal_type FROM annes_access_assignments")
    assert_equal [ "annes_access_permissions", "annes_access_roles" ],
      connection.foreign_keys(:annes_access_role_permissions).map(&:to_table).sort
    assert_equal [ "annes_access_roles" ], connection.foreign_keys(:annes_access_assignments).map(&:to_table)
    assert_includes connection.indexes(:annes_access_roles).map(&:name), "index_annes_access_roles_on_key"
    assert_includes connection.indexes(:annes_access_assignments).map(&:name), "index_annes_access_assignments_on_principal_and_role"
    assert connection.indexes(:annes_access_role_permissions).any? { |index|
      index.columns == %w[role_id permission_id] && index.unique
    }
  ensure
    reset_schema
  end

  test "does nothing when legacy RBAC tables have never been installed" do
    drop_tables

    RenameAnneAccessTablesToAnnesAccess.migrate(:up)

    connection = ActiveRecord::Base.connection
    assert_empty (OLD_TABLES + NEW_TABLES).select { |table| connection.data_source_exists?(table) }
  ensure
    reset_schema
  end

  test "restores legacy table names and rows on rollback" do
    create_legacy_schema
    connection = ActiveRecord::Base.connection
    connection.execute <<~SQL
      INSERT INTO anne_access_roles (key, name, system, created_at, updated_at)
      VALUES ('admin', 'Administrator', TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    RenameAnneAccessTablesToAnnesAccess.migrate(:up)
    RenameAnneAccessTablesToAnnesAccess.migrate(:down)

    assert_equal [ "admin" ], connection.select_values("SELECT key FROM anne_access_roles")
    assert_empty NEW_TABLES.select { |table| connection.data_source_exists?(table) }
    assert_equal [ "anne_access_roles" ], connection.foreign_keys(:anne_access_assignments).map(&:to_table)
  ensure
    reset_schema
  end

  private
    def create_legacy_schema
      drop_tables
      connection = ActiveRecord::Base.connection
      connection.create_table(:anne_access_roles) { |table| table.string :key, null: false; table.string :name, null: false; table.boolean :system, null: false, default: false; table.timestamps }
      connection.add_index :anne_access_roles, :key, unique: true
      connection.create_table(:anne_access_permissions) { |table| table.string :key, null: false; table.string :resource, null: false; table.string :action, null: false; table.timestamps }
      connection.add_index :anne_access_permissions, :key, unique: true
      connection.add_index :anne_access_permissions, %i[resource action], unique: true
      connection.create_table(:anne_access_role_permissions) { |table| table.references :role, null: false, foreign_key: { to_table: :anne_access_roles }; table.references :permission, null: false, foreign_key: { to_table: :anne_access_permissions }; table.timestamps }
      connection.add_index :anne_access_role_permissions, %i[role_id permission_id], unique: true
      connection.create_table(:anne_access_assignments) { |table| table.string :principal_type, null: false; table.bigint :principal_id, null: false; table.references :role, null: false, foreign_key: { to_table: :anne_access_roles }; table.timestamps }
      connection.add_index :anne_access_assignments, %i[principal_type principal_id role_id], unique: true, name: "index_anne_access_assignments_on_principal_and_role"
      connection.add_index :anne_access_assignments, %i[principal_type principal_id], name: "index_anne_access_assignments_on_principal"
    end

    def drop_tables
      connection = ActiveRecord::Base.connection
      (NEW_TABLES + OLD_TABLES).each { |table| connection.drop_table(table) if connection.data_source_exists?(table) }
    end

    def reset_schema
      drop_tables
      load File.expand_path("../dummy/db/schema.rb", __dir__)
    end
end
