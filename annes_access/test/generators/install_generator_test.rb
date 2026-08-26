require_relative "../test_helper"
require "rails/generators/test_case"
require "generators/annes_access/install_generator"

class AnnesAccess::InstallGeneratorTest < Rails::Generators::TestCase
  tests AnnesAccess::Generators::InstallGenerator
  destination Rails.root.join("tmp/generators/annes_access_install")

  setup do
    prepare_destination
  end

  teardown do
    FileUtils.rm_rf(destination_root)
  end

  test "copies initializer seed example and timestamped migrations" do
    run_generator

    assert_file "config/initializers/annes_access.rb", /AnnesAccess.configure/
    assert_file "db/seeds/annes_access.rb", /AnnesAccess::Role/
    assert_file "db/seeds/annes_access.rb", /role_permissions = \{/
    assert_file "db/seeds/annes_access.rb", /"admin" => \{/
    assert_file "db/seeds/annes_access.rb", /"viewer" => \{/
    assert_file "db/seeds/annes_access.rb", /AnnesAccess::RolePermission.find_or_create_by!/
    assert_migration "create_anne_access_roles.rb"
    assert_migration "create_anne_access_permissions.rb"
    assert_migration "create_anne_access_role_permissions.rb"
    assert_migration "create_anne_access_assignments.rb"
    assert_migration "rename_anne_access_tables_to_annes_access.rb"
  end

  test "does not duplicate migrations when rerun" do
    run_generator
    first_run_migrations = generated_migrations

    run_generator

    assert_equal first_run_migrations, generated_migrations
  end

  test "does not create duplicate generated files when legacy files exist" do
    legacy_initializer = File.join(destination_root, "config/initializers/anne_access.rb")
    legacy_seed = File.join(destination_root, "db/seeds/anne_access.rb")
    FileUtils.mkdir_p(File.dirname(legacy_initializer))
    FileUtils.mkdir_p(File.dirname(legacy_seed))
    File.write(legacy_initializer, "AnneAccess.configure do |config|\nend\n")
    File.write(legacy_seed, "# legacy access seed\n")

    run_generator

    assert_file "config/initializers/anne_access.rb", /AnneAccess.configure/
    assert_file "db/seeds/anne_access.rb", /legacy access seed/
    assert_no_file "config/initializers/annes_access.rb"
    assert_no_file "db/seeds/annes_access.rb"
  end

  private
    def assert_migration(file_name)
      matches = generated_migrations.select { |path| path.end_with?("_#{file_name}") }
      assert_equal 1, matches.length, "Expected one generated migration ending with #{file_name}, found #{matches.inspect}"
      assert_match(/\A\d{14}_/, File.basename(matches.first))
    end

    def generated_migrations
      Dir[File.join(destination_root, "db/migrate/*.rb")].map { |path| path.delete_prefix("#{destination_root}/") }.sort
    end
end
