require "test_helper"

class SeedIdempotencyTest < ActiveSupport::TestCase
  test "restaurant loyalty seed can be loaded repeatedly" do
    Rails.application.load_seed

    counts = {
      accounts: Account.count,
      roles: AnnesAccess::Role.count,
      permissions: AnnesAccess::Permission.count,
      programs: AnnesLoyalty::LoyaltyProgram.count,
      locations: AnnesLoyalty::LoyaltyLocation.count,
      rewards: AnnesLoyalty::LoyaltyReward.count,
      customers: Customer.count,
      members: AnnesLoyalty::LoyaltyMember.count,
      receipts: Receipt.count,
      ledger_entries: AnnesLoyalty::LoyaltyLedgerEntry.count,
      customer_access_codes: Customer.where.not(access_code_digest: nil).count
    }

    Rails.application.load_seed

    assert_equal counts.fetch(:accounts), Account.count
    assert_equal counts.fetch(:roles), AnnesAccess::Role.count
    assert_equal counts.fetch(:permissions), AnnesAccess::Permission.count
    assert_equal counts.fetch(:programs), AnnesLoyalty::LoyaltyProgram.count
    assert_equal counts.fetch(:locations), AnnesLoyalty::LoyaltyLocation.count
    assert_equal counts.fetch(:rewards), AnnesLoyalty::LoyaltyReward.count
    assert_equal counts.fetch(:customers), Customer.count
    assert_equal counts.fetch(:members), AnnesLoyalty::LoyaltyMember.count
    assert_equal counts.fetch(:receipts), Receipt.count
    assert_equal counts.fetch(:ledger_entries), AnnesLoyalty::LoyaltyLedgerEntry.count
    assert_equal counts.fetch(:customer_access_codes), Customer.where.not(access_code_digest: nil).count
  end
end
