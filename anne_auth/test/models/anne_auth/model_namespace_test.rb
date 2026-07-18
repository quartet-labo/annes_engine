require "test_helper"

class AnneAuth::ModelNamespaceTest < ActiveSupport::TestCase
  test "host authentication models inherit engine implementations" do
    assert_operator CustomerAccount, :<, AnneAuth::Account
    assert_operator CustomerSession, :<, AnneAuth::AccountSession
    assert_operator CustomerAccountIdentity, :<, AnneAuth::AccountIdentity
    assert_operator CustomerAccountVerificationToken, :<, AnneAuth::AccountVerificationToken
    assert_operator CustomerAccountPasswordResetToken, :<, AnneAuth::AccountPasswordResetToken
    assert_operator CustomerAccountInvitationToken, :<, AnneAuth::AccountInvitationToken
  end

  test "invitation token mapping uses the configured host classes and tables" do
    defaults = AnneAuth::Configuration.new

    assert_equal "AnneAuth::AccountInvitationToken", defaults.account_invitation_token_class_name
    assert_equal "account_invitation_tokens", defaults.account_invitation_token_table_name
    assert_respond_to defaults.account_invitation_url, :call

    assert_equal CustomerAccountInvitationToken, AnneAuth.configuration.account_invitation_token_class
    assert_equal "customer_account_invitation_tokens", AnneAuth.configuration.account_invitation_token_table_name

    association = CustomerAccount.reflect_on_association(:account_invitation_tokens)
    assert_not_nil association
    assert_equal "CustomerAccountInvitationToken", association.class_name
    assert_equal "customer_account_id", association.foreign_key
  end

  test "engine account does not include host project extensions" do
    assert_not_includes AnneAuth::Account.included_modules, CustomerAccountProfile
    assert_not_includes AnneAuth::Account.included_modules, CustomerAccountProjectAccess
  end

  test "host customer account keeps host extensions" do
    customer_account = customer_accounts(:verified)

    assert_kind_of CustomerAccountProfile, customer_account
    assert_kind_of CustomerAccountProjectAccess, customer_account
    assert_equal customers(:anan), customer_account.primary_customer
    assert_includes customer_account.accessible_projects, projects(:embroidery)
  end
end
