class CreateAuthenticationTables < ActiveRecord::Migration[8.1]
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

    create_table :sessions do |t|
      t.references :admin_user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

  end
end
