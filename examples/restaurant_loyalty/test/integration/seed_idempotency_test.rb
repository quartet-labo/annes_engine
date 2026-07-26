require "test_helper"

class SeedIdempotencyTest < ActiveSupport::TestCase
  test "restaurant loyalty seed can be loaded repeatedly" do
    Rails.application.load_seed

    counts = {
      accounts: Account.count,
      roles: AnneAccess::Role.count,
      permissions: AnneAccess::Permission.count,
      programs: AnneLoyalty::LoyaltyProgram.count,
      locations: AnneLoyalty::LoyaltyLocation.count,
      rewards: AnneLoyalty::LoyaltyReward.count,
      customers: Customer.count,
      members: AnneLoyalty::LoyaltyMember.count,
      receipts: Receipt.count,
      ledger_entries: AnneLoyalty::LoyaltyLedgerEntry.count
    }

    Rails.application.load_seed

    assert_equal counts.fetch(:accounts), Account.count
    assert_equal counts.fetch(:roles), AnneAccess::Role.count
    assert_equal counts.fetch(:permissions), AnneAccess::Permission.count
    assert_equal counts.fetch(:programs), AnneLoyalty::LoyaltyProgram.count
    assert_equal counts.fetch(:locations), AnneLoyalty::LoyaltyLocation.count
    assert_equal counts.fetch(:rewards), AnneLoyalty::LoyaltyReward.count
    assert_equal counts.fetch(:customers), Customer.count
    assert_equal counts.fetch(:members), AnneLoyalty::LoyaltyMember.count
    assert_equal counts.fetch(:receipts), Receipt.count
    assert_equal counts.fetch(:ledger_entries), AnneLoyalty::LoyaltyLedgerEntry.count
  end
end
