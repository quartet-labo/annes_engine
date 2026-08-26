class CreateAnneAccessRoles < ActiveRecord::Migration[8.1]
  def change
    create_table :anne_access_roles do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :system, null: false, default: false
      t.timestamps

      t.index :key, unique: true
    end
  end
end
