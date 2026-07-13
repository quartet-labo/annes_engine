ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"
require_relative "support/access_helpers"

module ReservationManagementSeedTestHelper
  SEED_PASSWORD = "password-1234"
  SEED_TIME = Time.zone.local(2026, 7, 13, 8).freeze

  def load_reservation_management_seeds
    Rails.application.load_seed
  end

  def with_reservation_management_seeds(&block)
    travel_to(SEED_TIME) do
      load_reservation_management_seeds
      block.call
    end
  end

  def sign_in_seed_account(email, remote_addr: "192.0.2.10")
    post "/admin/session",
      params: { email:, password: SEED_PASSWORD },
      headers: { "REMOTE_ADDR" => remote_addr }
    assert_redirected_to "/admin/home"
  end
end

class ActiveSupport::TestCase
  include AccessHelpers
  include ReservationManagementSeedTestHelper
end
