class CreateAnneAccessPermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :anne_access_permissions do |t|
      t.string :key, null: false
      t.string :resource, null: false
      t.string :action, null: false
      t.text :description
      t.timestamps

      t.index :key, unique: true
      t.index [ :resource, :action ], unique: true
    end
  end
end
