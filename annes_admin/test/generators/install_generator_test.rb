require_relative "../test_helper"
require "rails/generators/test_case"
require "generators/annes_admin/install_generator"

class AnnesAdmin::InstallGeneratorTest < Rails::Generators::TestCase
  tests AnnesAdmin::Generators::InstallGenerator
  destination Rails.root.join("tmp/generators/annes_admin")

  setup do
    prepare_destination
    FileUtils.mkdir_p File.join(destination_root, "config")
    File.write File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n"
  end

  test "creates initializer and mounts engine" do
    run_generator

    assert_file "config/initializers/annes_admin.rb", /AnnesAdmin.configure/
    assert_file "app/admin/resources/users.rb", /AnnesAdmin.resource :users/
    assert_file "config/routes.rb", /mount AnnesAdmin::Engine => "\/admin"/
  end

  test "does not duplicate mount route when rerun" do
    run_generator
    run_generator

    routes = File.read File.join(destination_root, "config/routes.rb")
    assert_equal 1, routes.scan("mount AnnesAdmin::Engine").length
  end

  test "does not create a second initializer when the legacy initializer exists" do
    FileUtils.mkdir_p File.join(destination_root, "config/initializers")
    File.write File.join(destination_root, "config/initializers/anne_admin.rb"), "# migrate me\n"

    run_generator

    assert_no_file "config/initializers/annes_admin.rb"
  end
end
