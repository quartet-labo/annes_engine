require "test_helper"

class AnnesAuth::BootstrapClaimTest < ActiveSupport::TestCase
  setup do
    AnnesAuth::BootstrapClaim.delete_all
  end

  test "requires a unique purpose" do
    AnnesAuth::BootstrapClaim.create!(purpose: AnnesAuth::BootstrapClaim::INITIAL_ACCOUNT_PURPOSE)
    duplicate = AnnesAuth::BootstrapClaim.new(purpose: AnnesAuth::BootstrapClaim::INITIAL_ACCOUNT_PURPOSE)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:purpose], "has already been taken"
  end

  test "uses the configured bootstrap claim table" do
    assert_equal "annes_auth_bootstrap_claims", AnnesAuth::Configuration.new.bootstrap_claim_table_name
    assert_equal "annes_auth_bootstrap_claims", AnnesAuth::BootstrapClaim.table_name
  end
end
