class CreateAnneAccessAssignments < ActiveRecord::Migration[8.1]
  def change
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
