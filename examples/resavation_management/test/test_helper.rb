ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require_relative "support/access_helpers"

class ActiveSupport::TestCase
  include AccessHelpers
end
