require "test_helper"

class AnnesAuth::ModelNamespaceTest < ActiveSupport::TestCase
  test "host authentication models inherit engine implementations" do
    assert_operator CustomerAccount, :<, AnnesAuth::Account
    assert_operator CustomerSession, :<, AnnesAuth::AccountSession
    assert_operator CustomerAccountIdentity, :<, AnnesAuth::AccountIdentity
    assert_operator CustomerAccountVerificationToken, :<, AnnesAuth::AccountVerificationToken
    assert_operator CustomerAccountPasswordResetToken, :<, AnnesAuth::AccountPasswordResetToken
    assert_operator CustomerAccountInvitationToken, :<, AnnesAuth::AccountInvitationToken
  end

  test "invitation token mapping uses the configured host classes and tables" do
    defaults = AnnesAuth::Configuration.new

    assert_equal "AnnesAuth::AccountInvitationToken", defaults.account_invitation_token_class_name
    assert_equal "account_invitation_tokens", defaults.account_invitation_token_table_name
    assert_respond_to defaults.account_invitation_url, :call
    assert_equal "annes_auth_bootstrap_claims", defaults.bootstrap_claim_table_name
    assert_respond_to defaults.after_account_bootstrapped, :call

    assert_equal CustomerAccountInvitationToken, AnnesAuth.configuration.account_invitation_token_class
    assert_equal "customer_account_invitation_tokens", AnnesAuth.configuration.account_invitation_token_table_name
    assert_equal "annes_auth_bootstrap_claims", AnnesAuth::BootstrapClaim.table_name

    association = CustomerAccount.reflect_on_association(:account_invitation_tokens)
    assert_not_nil association
    assert_equal "CustomerAccountInvitationToken", association.class_name
    assert_equal "customer_account_id", association.foreign_key
  end

  test "engine account does not include host project extensions" do
    assert_not_includes AnnesAuth::Account.included_modules, CustomerAccountProfile
    assert_not_includes AnnesAuth::Account.included_modules, CustomerAccountProjectAccess
  end

  test "host customer account keeps host extensions" do
    customer_account = customer_accounts(:verified)

    assert_kind_of CustomerAccountProfile, customer_account
    assert_kind_of CustomerAccountProjectAccess, customer_account
    assert_equal customers(:anan), customer_account.primary_customer
    assert_includes customer_account.accessible_projects, projects(:embroidery)
  end
end
