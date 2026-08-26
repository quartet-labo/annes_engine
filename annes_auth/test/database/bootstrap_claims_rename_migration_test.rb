require "test_helper"
require_relative "../../db/migrate/20260826000000_rename_anne_auth_bootstrap_claims_to_annes_auth_bootstrap_claims"

class AnnesAuth::BootstrapClaimsRenameMigrationTest < ActiveSupport::TestCase
  OLD_TABLE = :anne_auth_bootstrap_claims
  NEW_TABLE = :annes_auth_bootstrap_claims

  test "migrates legacy bootstrap claims and custom indexes to the Annes prefix" do
    connection = ActiveRecord::Base.connection
    connection.drop_table(NEW_TABLE) if connection.data_source_exists?(NEW_TABLE)
    connection.drop_table(OLD_TABLE) if connection.data_source_exists?(OLD_TABLE)
    connection.create_table(OLD_TABLE) do |table|
      table.string :purpose, null: false
      table.string :account_class_name
      table.bigint :account_id
      table.string :last_delivery_status
      table.datetime :completed_at
      table.timestamps
    end
    connection.add_index(OLD_TABLE, :purpose, unique: true, name: "idx_anne_auth_bootstrap_claims_on_purpose")
    connection.add_index(OLD_TABLE, [ :account_class_name, :account_id ], name: "idx_anne_auth_bootstrap_claims_on_account")
    connection.execute <<~SQL
      INSERT INTO anne_auth_bootstrap_claims (purpose, account_class_name, created_at, updated_at)
      VALUES ('initial_account', 'AnneAuth::Account', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    RenameAnneAuthBootstrapClaimsToAnnesAuthBootstrapClaims.migrate(:up)

    assert_not connection.data_source_exists?(OLD_TABLE)
    assert connection.data_source_exists?(NEW_TABLE)
    assert_equal [ "initial_account" ], connection.select_values("SELECT purpose FROM annes_auth_bootstrap_claims")
    assert_equal [ "AnnesAuth::Account" ], connection.select_values("SELECT account_class_name FROM annes_auth_bootstrap_claims")
    assert_equal [
      "idx_annes_auth_bootstrap_claims_on_account",
      "idx_annes_auth_bootstrap_claims_on_purpose"
    ], connection.indexes(NEW_TABLE).map(&:name).sort
  ensure
    connection&.drop_table(NEW_TABLE) if connection&.data_source_exists?(NEW_TABLE)
    connection&.drop_table(OLD_TABLE) if connection&.data_source_exists?(OLD_TABLE)
    load File.expand_path("../dummy/db/schema.rb", __dir__)
  end

  test "does nothing when bootstrap claims have never been installed" do
    connection = ActiveRecord::Base.connection
    connection.drop_table(NEW_TABLE) if connection.data_source_exists?(NEW_TABLE)
    connection.drop_table(OLD_TABLE) if connection.data_source_exists?(OLD_TABLE)

    RenameAnneAuthBootstrapClaimsToAnnesAuthBootstrapClaims.migrate(:up)

    assert_not connection.data_source_exists?(OLD_TABLE)
    assert_not connection.data_source_exists?(NEW_TABLE)
  ensure
    connection&.drop_table(NEW_TABLE) if connection&.data_source_exists?(NEW_TABLE)
    connection&.drop_table(OLD_TABLE) if connection&.data_source_exists?(OLD_TABLE)
    load File.expand_path("../dummy/db/schema.rb", __dir__)
  end

  test "is safe when the Annes bootstrap table already exists" do
    connection = ActiveRecord::Base.connection
    connection.drop_table(NEW_TABLE) if connection.data_source_exists?(NEW_TABLE)
    connection.drop_table(OLD_TABLE) if connection.data_source_exists?(OLD_TABLE)
    connection.create_table(NEW_TABLE) do |table|
      table.string :purpose, null: false
      table.string :account_class_name
      table.bigint :account_id
      table.string :last_delivery_status
      table.datetime :completed_at
      table.timestamps
    end
    connection.execute <<~SQL
      INSERT INTO annes_auth_bootstrap_claims (purpose, account_class_name, created_at, updated_at)
      VALUES ('initial_account', 'AnnesAuth::Account', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL

    RenameAnneAuthBootstrapClaimsToAnnesAuthBootstrapClaims.migrate(:up)

    assert_equal [ "AnnesAuth::Account" ], connection.select_values("SELECT account_class_name FROM annes_auth_bootstrap_claims")
  ensure
    connection&.drop_table(NEW_TABLE) if connection&.data_source_exists?(NEW_TABLE)
    connection&.drop_table(OLD_TABLE) if connection&.data_source_exists?(OLD_TABLE)
    load File.expand_path("../dummy/db/schema.rb", __dir__)
  end
end
