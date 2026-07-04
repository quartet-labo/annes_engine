require_relative "../test_helper"
require "rails/generators/test_case"
require "generators/anne_admin/install_generator"

class AnneAdmin::InstallGeneratorTest < Rails::Generators::TestCase
  tests AnneAdmin::Generators::InstallGenerator
  destination Rails.root.join("tmp/generators/anne_admin")

  setup do
    prepare_destination
    FileUtils.mkdir_p File.join(destination_root, "config")
    File.write File.join(destination_root, "config/routes.rb"), "Rails.application.routes.draw do\nend\n"
  end

  test "creates initializer and mounts engine" do
    run_generator

    assert_file "config/initializers/anne_admin.rb", /AnneAdmin.configure/
    assert_file "app/admin/resources/users.rb", /AnneAdmin.resource :users/
    assert_file "config/routes.rb", /mount AnneAdmin::Engine => "\/admin"/
  end

  test "does not duplicate mount route when rerun" do
    run_generator
    run_generator

    routes = File.read File.join(destination_root, "config/routes.rb")
    assert_equal 1, routes.scan("mount AnneAdmin::Engine").length
  end
end
