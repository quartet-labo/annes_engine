require "test_helper"

class AnneAuth::BootstrapClaimTest < ActiveSupport::TestCase
  setup do
    AnneAuth::BootstrapClaim.delete_all
  end

  test "requires a unique purpose" do
    AnneAuth::BootstrapClaim.create!(purpose: AnneAuth::BootstrapClaim::INITIAL_ACCOUNT_PURPOSE)
    duplicate = AnneAuth::BootstrapClaim.new(purpose: AnneAuth::BootstrapClaim::INITIAL_ACCOUNT_PURPOSE)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:purpose], "has already been taken"
  end

  test "uses the configured bootstrap claim table" do
    assert_equal "anne_auth_bootstrap_claims", AnneAuth::Configuration.new.bootstrap_claim_table_name
    assert_equal "anne_auth_bootstrap_claims", AnneAuth::BootstrapClaim.table_name
  end
end
