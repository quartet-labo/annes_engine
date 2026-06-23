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
    assert_file "config/routes.rb", /mount AnneAdmin::Engine => "\/admin"/
  end
end
