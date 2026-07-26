ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"
require "securerandom"

def ensure_dummy_database!
  ActiveRecord::Tasks::DatabaseTasks.database_configuration = Rails.application.config.database_configuration
  ActiveRecord::Tasks::DatabaseTasks.env = Rails.env
  ActiveRecord::Tasks::DatabaseTasks.create_current
rescue ActiveRecord::DatabaseAlreadyExists
  # The dummy database is reused between local test runs.
ensure
  ActiveRecord::Base.establish_connection
end

ensure_dummy_database!

ActiveRecord.maintain_test_schema = false
require "rails/test_help"

ActiveRecord::Migration.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)
ActiveSupport::TestCase.fixture_paths = [ File.expand_path("fixtures", __dir__) ]

module AnneLoyalty
  module TestConfiguration
    def before_setup
      AnneLoyalty.reset_configuration!
      super
    end

    def after_teardown
      super
      AnneLoyalty.reset_configuration!
    end
  end

  class TestCase < ActiveSupport::TestCase
    include TestConfiguration

    def create_program(code: "cafe", name: "Cafe")
      AnneLoyalty::LoyaltyProgram.create!(
        code:,
        name:,
        point_name: "pt",
        earn_unit_amount_cents: 100,
        earn_points_per_unit: 1,
        default_expiration_months: 12
      )
    end

    def create_location(program = create_program, code: "main")
      AnneLoyalty::LoyaltyLocation.create!(
        loyalty_program: program,
        code:,
        name: "#{code.to_s.titleize} Store",
        time_zone: "Asia/Tokyo"
      )
    end

    def create_member(program: create_program, owner: Account.create!(email: "member-#{SecureRandom.hex(4)}@example.com"), member_key: "CARD-#{SecureRandom.hex(3).upcase}")
      AnneLoyalty::LoyaltyMember.create!(
        loyalty_program: program,
        owner:,
        member_key:
      )
    end
  end
end
