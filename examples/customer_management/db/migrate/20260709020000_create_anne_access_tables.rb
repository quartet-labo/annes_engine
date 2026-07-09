class CreateAnneAccessTables < ActiveRecord::Migration[8.1]
  def change
    create_table :anne_access_roles do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :system, null: false, default: false
      t.timestamps

      t.index :key, unique: true
    end

    create_table :anne_access_permissions do |t|
      t.string :key, null: false
      t.string :resource, null: false
      t.string :action, null: false
      t.text :description
      t.timestamps

      t.index :key, unique: true
      t.index [ :resource, :action ], unique: true
    end

    create_table :anne_access_role_permissions do |t|
      t.references :role, null: false, foreign_key: { to_table: :anne_access_roles }
      t.references :permission, null: false, foreign_key: { to_table: :anne_access_permissions }
      t.timestamps

      t.index [ :role_id, :permission_id ], unique: true
    end

    create_table :anne_access_assignments do |t|
      t.string :principal_type, null: false
      t.bigint :principal_id, null: false
      t.references :role, null: false, foreign_key: { to_table: :anne_access_roles }
      t.timestamps

      t.index [ :principal_type, :principal_id, :role_id ], unique: true, name: "index_anne_access_assignments_on_principal_and_role"
      t.index [ :principal_type, :principal_id ], name: "index_anne_access_assignments_on_principal"
    end
  end
end
