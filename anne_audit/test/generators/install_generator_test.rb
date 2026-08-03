require_relative "../test_helper"
require "rails/generators/test_case"
require "generators/anne_audit/install_generator"

class AnneAudit::InstallGeneratorTest < Rails::Generators::TestCase
  tests AnneAudit::Generators::InstallGenerator
  destination Rails.root.join("tmp/generators/anne_audit_install")

  setup do
    prepare_destination
  end

  teardown do
    FileUtils.rm_rf(destination_root)
  end

  test "copies initializer and timestamped migrations" do
    run_generator

    assert_file "config/initializers/anne_audit.rb", /AnneAudit.configure/
    assert_file "config/initializers/anne_audit.rb", /raise_on_persistence_error/
    assert_file "config/initializers/anne_audit.rb", /notification_subscribers.register/
    assert_migration "create_anne_audit_events.rb"
  end

  test "does not duplicate migrations when rerun" do
    run_generator
    first_run_migrations = generated_migrations

    run_generator

    assert_equal first_run_migrations, generated_migrations
  end

  test "preserves an existing initializer when rerun" do
    run_generator
    initializer_path = File.join(destination_root, "config/initializers/anne_audit.rb")
    File.open(initializer_path, "a") { |file| file << "\n# host application customization\n" }

    run_generator

    initializer = File.read(initializer_path)
    assert_equal 1, initializer.scan("AnneAudit.configure").length
    assert_includes initializer, "# host application customization"
    assert_equal 1, generated_migrations.count { |path| path.end_with?("_create_anne_audit_events.rb") }
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
