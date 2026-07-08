class CreateAuthenticationTables < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :name
      t.string :role, null: false, default: "admin"
      t.datetime :email_verified_at
      t.datetime :last_sign_in_at
      t.datetime :disabled_at

      t.timestamps
    end
    add_index :accounts, :email, unique: true
    add_index :accounts, :email_verified_at
    add_index :accounts, :disabled_at

    create_table :account_sessions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

  end
end
