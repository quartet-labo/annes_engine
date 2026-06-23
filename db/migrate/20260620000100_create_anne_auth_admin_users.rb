class CreateAnneAuthAdminUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name
      t.string :role, null: false, default: "admin"
      t.datetime :last_sign_in_at

      t.timestamps
    end

    add_index :admin_users, :email, unique: true
  end
end
