require "test_helper"
require "rails/generators/test_case"
require "generators/anne_auth/install_generator"

class AnneAuth::InstallGeneratorTest < Rails::Generators::TestCase
  tests AnneAuth::Generators::InstallGenerator
  destination Rails.root.join("tmp/generators/anne_auth_install")

  setup do
    prepare_destination
  end

  teardown do
    FileUtils.rm_rf(destination_root)
  end

  test "copies initializer route example and timestamped migrations" do
    run_generator

    assert_file "config/initializers/anne_auth.rb", /AnneAuth.configure/
    assert_file "config/initializers/anne_auth.rb", /after_account_email_verification_path/
    assert_file "config/routes/anne_auth.rb", /mount AnneAuth::Engine/
    assert_migration "create_anne_auth_accounts.rb"
    assert_migration "create_anne_auth_account_sessions.rb"
    assert_migration "create_anne_auth_account_password_reset_tokens.rb"
    assert_no_migration "create_anne_auth_admin_users.rb"
    assert_no_migration "create_anne_auth_admin_sessions.rb"
    assert_no_file "db/migrate/20260620000100_create_anne_auth_admin_users.rb"
  end

  test "copies legacy admin migrations when requested" do
    run_generator [ "--legacy-admin" ]

    assert_migration "create_anne_auth_accounts.rb"
    assert_migration "create_anne_auth_account_sessions.rb"
    assert_migration "create_anne_auth_admin_users.rb"
    assert_migration "create_anne_auth_admin_sessions.rb"
  end

  test "does not duplicate migrations when rerun" do
    run_generator
    first_run_migrations = generated_migrations

    run_generator

    assert_equal first_run_migrations, generated_migrations
  end

  private
    def assert_migration(file_name)
      matches = generated_migrations.select { |path| path.end_with?("_#{file_name}") }
      assert_equal 1, matches.length, "Expected one generated migration ending with #{file_name}, found #{matches.inspect}"
      assert_match(/\A\d{14}_/, File.basename(matches.first))
    end

    def assert_no_migration(file_name)
      matches = generated_migrations.select { |path| path.end_with?("_#{file_name}") }
      assert_empty matches, "Expected no generated migration ending with #{file_name}, found #{matches.inspect}"
    end

    def generated_migrations
      Dir[File.join(destination_root, "db/migrate/*.rb")].map { |path| path.delete_prefix("#{destination_root}/") }.sort
    end
end
