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

  test "copies initializer route example and migrations" do
    run_generator

    assert_file "config/initializers/anne_auth.rb", /AnneAuth.configure/
    assert_file "config/routes/anne_auth.rb", /mount AnneAuth::Engine/
    assert_file "db/migrate/20260620000100_create_anne_auth_admin_users.rb"
    assert_file "db/migrate/20260620000700_create_anne_auth_account_password_reset_tokens.rb"
  end
end
