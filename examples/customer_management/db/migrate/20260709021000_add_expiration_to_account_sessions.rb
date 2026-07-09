class AddExpirationToAccountSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :account_sessions, :expires_at, :datetime unless column_exists?(:account_sessions, :expires_at)
    add_column :account_sessions, :last_used_at, :datetime unless column_exists?(:account_sessions, :last_used_at)

    expires_at = quote(2.weeks.from_now)
    last_used_at = quote(Time.current)
    execute <<~SQL.squish
      UPDATE account_sessions
      SET expires_at = #{expires_at},
          last_used_at = COALESCE(last_used_at, updated_at, created_at, #{last_used_at})
      WHERE expires_at IS NULL
    SQL

    change_column_null :account_sessions, :expires_at, false
    add_index :account_sessions, :expires_at unless index_exists?(:account_sessions, :expires_at)
  end

  def down
    remove_index :account_sessions, :expires_at if index_exists?(:account_sessions, :expires_at)
    remove_column :account_sessions, :last_used_at if column_exists?(:account_sessions, :last_used_at)
    remove_column :account_sessions, :expires_at if column_exists?(:account_sessions, :expires_at)
  end
end
