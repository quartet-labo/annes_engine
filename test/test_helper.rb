ENV["RAILS_ENV"] ||= "test"

require_relative "../../../config/environment"
require "rails/test_help"

module AnneAdmin
  module TestConfiguration
    def before_setup
      AnneAdmin.reset_configuration!
      super
    end

    def after_teardown
      super
      AnneAdmin.reset_configuration!
      load Rails.root.join("config/initializers/anne_admin.rb")
    end
  end

  class TestCase < ActiveSupport::TestCase
    include TestConfiguration

    fixtures :all
  end

  class IntegrationTest < ActionDispatch::IntegrationTest
    include TestConfiguration

    fixtures :all
  end
end
