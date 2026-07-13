class CreateAnneAuthAccountSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :account_sessions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.datetime :expires_at, null: false
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :account_sessions, :expires_at
  end
end
