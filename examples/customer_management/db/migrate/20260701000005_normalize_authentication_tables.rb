class NormalizeAuthenticationTables < ActiveRecord::Migration[8.1]
  def up
    remove_legacy_session_foreign_key
    rename_table :admin_users, :accounts if table_exists?(:admin_users) && !table_exists?(:accounts)
    rename_table :sessions, :account_sessions if table_exists?(:sessions) && !table_exists?(:account_sessions)

    normalize_accounts_table
    normalize_account_sessions_table
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private
    def normalize_accounts_table
      return unless table_exists?(:accounts)

      add_column :accounts, :email_verified_at, :datetime unless column_exists?(:accounts, :email_verified_at)
      add_column :accounts, :disabled_at, :datetime unless column_exists?(:accounts, :disabled_at)

      rename_index_if_exists :accounts, "index_admin_users_on_email", "index_accounts_on_email"

      add_index :accounts, :email, unique: true unless index_exists?(:accounts, :email, unique: true)
      add_index :accounts, :email_verified_at unless index_exists?(:accounts, :email_verified_at)
      add_index :accounts, :disabled_at unless index_exists?(:accounts, :disabled_at)
    end

    def normalize_account_sessions_table
      return unless table_exists?(:account_sessions)

      if column_exists?(:account_sessions, :admin_user_id) && !column_exists?(:account_sessions, :account_id)
        rename_column :account_sessions, :admin_user_id, :account_id
      end

      rename_index_if_exists :account_sessions, "index_sessions_on_admin_user_id", "index_account_sessions_on_account_id"

      add_index :account_sessions, :account_id unless index_exists?(:account_sessions, :account_id)
      add_foreign_key :account_sessions, :accounts unless foreign_key_exists?(:account_sessions, :accounts)
    end

    def remove_legacy_session_foreign_key
      return unless table_exists?(:sessions)

      if foreign_key_exists?(:sessions, :admin_users)
        remove_foreign_key :sessions, :admin_users
      elsif foreign_key_exists?(:sessions, :accounts)
        remove_foreign_key :sessions, :accounts
      end
    end

    def rename_index_if_exists(table_name, old_name, new_name)
      return unless index_named?(table_name, old_name)
      return if index_named?(table_name, new_name)

      rename_index table_name, old_name, new_name
    end

    def index_named?(table_name, index_name)
      indexes(table_name).any? { |index| index.name == index_name }
    end
end
