ENV["RAILS_ENV"] = "test"
ENV.delete("DATABASE_URL")
if ENV["COVERAGE"] == "true"
  require "simplecov"
  SimpleCov.start do
    root File.expand_path("..", __dir__)
    coverage_dir "coverage"
    track_files "{app,lib}/**/*.rb"
    add_filter "/test/"
    enable_coverage :branch
    command_name "intake-tests"
  end
end
require_relative "dummy/config/environment"
require "rails/test_help"

class TestDefinitionAuthorizer
  def prepare_context(controller, admin:) = admin
  def scope_definitions(relation, context:) = relation
  def authorize!(action:, record:, context:) = true
end
AnnesIntake.configuration.definition_authorizer = TestDefinitionAuthorizer.new
