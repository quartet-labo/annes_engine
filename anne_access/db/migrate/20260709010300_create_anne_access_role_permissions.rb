class CreateAnneAccessRolePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :anne_access_role_permissions do |t|
      t.references :role, null: false, foreign_key: { to_table: :anne_access_roles }
      t.references :permission, null: false, foreign_key: { to_table: :anne_access_permissions }
      t.timestamps

      t.index [ :role_id, :permission_id ], unique: true
    end
  end
end
