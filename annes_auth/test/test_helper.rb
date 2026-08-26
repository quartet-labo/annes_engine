ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"

def ensure_dummy_database!
  ActiveRecord::Tasks::DatabaseTasks.database_configuration = Rails.application.config.database_configuration
  ActiveRecord::Tasks::DatabaseTasks.env = Rails.env
  ActiveRecord::Tasks::DatabaseTasks.create_current
rescue ActiveRecord::Tasks::DatabaseAlreadyExists
  # The dummy database is reused between local test runs.
ensure
  ActiveRecord::Base.establish_connection
end

ensure_dummy_database!

ActiveRecord.maintain_test_schema = false
require "rails/test_help"
require "bcrypt"
require "omniauth"

ActiveRecord::Migration.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)
ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]

module ActiveSupport
  class TestCase
    fixtures :all

    setup do
      Rails.cache.clear
    end
  end
end
