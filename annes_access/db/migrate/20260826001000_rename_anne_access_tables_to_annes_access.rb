class RenameAnneAccessTablesToAnnesAccess < ActiveRecord::Migration[8.1]
  TABLE_RENAMES = {
    anne_access_roles: :annes_access_roles,
    anne_access_permissions: :annes_access_permissions,
    anne_access_role_permissions: :annes_access_role_permissions,
    anne_access_assignments: :annes_access_assignments
  }.freeze

  INDEX_RENAMES = {
    annes_access_roles: {
      "index_anne_access_roles_on_key" => "index_annes_access_roles_on_key"
    },
    annes_access_permissions: {
      "index_anne_access_permissions_on_key" => "index_annes_access_permissions_on_key",
      "index_anne_access_permissions_on_resource_and_action" => "index_annes_access_permissions_on_resource_and_action"
    },
    annes_access_role_permissions: {
      "index_anne_access_role_permissions_on_role_id" => "index_annes_access_role_permissions_on_role_id",
      "index_anne_access_role_permissions_on_permission_id" => "index_annes_access_role_permissions_on_permission_id",
      "idx_on_role_id_permission_id_anne_access" => "idx_on_role_id_permission_id_annes_access"
    },
    annes_access_assignments: {
      "index_anne_access_assignments_on_role_id" => "index_annes_access_assignments_on_role_id",
      "index_anne_access_assignments_on_principal" => "index_annes_access_assignments_on_principal",
      "index_anne_access_assignments_on_principal_and_role" => "index_annes_access_assignments_on_principal_and_role"
    }
  }.freeze

  def up
    rename_tables(TABLE_RENAMES)
    rename_indexes(INDEX_RENAMES)
  end

  def down
    rename_indexes(INDEX_RENAMES.transform_values(&:invert))
    rename_tables(TABLE_RENAMES.invert)
  end

  private
    def rename_tables(renames)
      renames.each { |from, to| rename_table_if_needed(from, to) }
    end

    def rename_table_if_needed(from, to)
      return unless table_exists?(from)
      raise "Cannot rename #{from} to #{to}: both tables exist" if table_exists?(to)

      rename_table(from, to)
    end

    def rename_indexes(renames)
      renames.each do |table, names|
        next unless table_exists?(table)

        names.each do |from, to|
          rename_index(table, from, to) if index_exists?(table, name: from)
        end
      end
    end
end
