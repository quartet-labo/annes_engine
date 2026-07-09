require_relative "../test_helper"
require "rails/generators/test_case"
require "generators/anne_access/install_generator"

class AnneAccess::InstallGeneratorTest < Rails::Generators::TestCase
  tests AnneAccess::Generators::InstallGenerator
  destination Rails.root.join("tmp/generators/anne_access_install")

  setup do
    prepare_destination
  end

  teardown do
    FileUtils.rm_rf(destination_root)
  end

  test "copies initializer seed example and timestamped migrations" do
    run_generator

    assert_file "config/initializers/anne_access.rb", /AnneAccess.configure/
    assert_file "db/seeds/anne_access.rb", /AnneAccess::Role/
    assert_migration "create_anne_access_roles.rb"
    assert_migration "create_anne_access_permissions.rb"
    assert_migration "create_anne_access_role_permissions.rb"
    assert_migration "create_anne_access_assignments.rb"
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

    def generated_migrations
      Dir[File.join(destination_root, "db/migrate/*.rb")].map { |path| path.delete_prefix("#{destination_root}/") }.sort
    end
end
