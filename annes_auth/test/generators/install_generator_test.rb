require "test_helper"
require "rails/generators/test_case"
require "generators/annes_auth/install_generator"

class AnnesAuth::InstallGeneratorTest < Rails::Generators::TestCase
  tests AnnesAuth::Generators::InstallGenerator
  destination Rails.root.join("tmp/generators/annes_auth_install")

  setup do
    prepare_destination
  end

  teardown do
    FileUtils.rm_rf(destination_root)
  end

  test "copies initializer route example and timestamped migrations" do
    run_generator

    assert_file "config/initializers/annes_auth.rb", /AnnesAuth.configure/
    assert_file "config/initializers/annes_auth.rb", /after_account_email_verification_path/
    assert_file "config/initializers/annes_auth.rb", /account_invitation_token_class_name/
    assert_file "config/initializers/annes_auth.rb", /account_invitation_token_table_name/
    assert_file "config/initializers/annes_auth.rb", /account_invitation_url/
    assert_file "config/initializers/annes_auth.rb", /after_account_bootstrapped/
    assert_file "config/initializers/annes_auth.rb" do |content|
      assert_no_match(/legacy AdminUser/, content)
      assert_no_match(/admin_user_class_name/, content)
    end
    assert_file "config/routes/annes_auth.rb", /mount AnnesAuth::Engine/
    assert_migration "create_anne_auth_accounts.rb"
    assert_migration "create_anne_auth_account_sessions.rb"
    assert_migration "create_anne_auth_account_password_reset_tokens.rb"
    assert_migration "create_anne_auth_account_invitation_tokens.rb"
    assert_migration "create_anne_auth_bootstrap_claims.rb"
    assert_migration "rename_anne_auth_bootstrap_claims_to_annes_auth_bootstrap_claims.rb"
    assert_no_migration "create_anne_auth_admin_users.rb"
    assert_no_migration "create_anne_auth_admin_sessions.rb"
    assert_no_file "db/migrate/20260620000100_create_anne_auth_admin_users.rb"
  end

  test "does not duplicate migrations when rerun" do
    run_generator
    first_run_migrations = generated_migrations

    run_generator

    assert_equal first_run_migrations, generated_migrations
  end

  test "preserves an existing initializer when rerun" do
    run_generator
    initializer_path = File.join(destination_root, "config/initializers/annes_auth.rb")
    File.open(initializer_path, "a") { |file| file << "\n# host application customization\n" }

    run_generator

    initializer = File.read(initializer_path)
    assert_equal 1, initializer.scan("AnnesAuth.configure").length
    assert_includes initializer, "# host application customization"
    assert_equal 1, generated_migrations.count { |path| path.end_with?("_create_anne_auth_account_invitation_tokens.rb") }
    assert_equal 1, generated_migrations.count { |path| path.end_with?("_create_anne_auth_bootstrap_claims.rb") }
    assert_equal 1, generated_migrations.count { |path| path.end_with?("_rename_anne_auth_bootstrap_claims_to_annes_auth_bootstrap_claims.rb") }
  end

  test "does not create a second initializer when a legacy initializer exists" do
    legacy_initializer = File.join(destination_root, "config/initializers/anne_auth.rb")
    FileUtils.mkdir_p(File.dirname(legacy_initializer))
    File.write(legacy_initializer, "AnneAuth.configure do |config|\nend\n")

    run_generator

    assert_file "config/initializers/anne_auth.rb", /AnneAuth.configure/
    assert_no_file "config/initializers/annes_auth.rb"
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
