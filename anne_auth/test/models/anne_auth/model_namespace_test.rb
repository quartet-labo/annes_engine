require "test_helper"

class AnneAuth::ModelNamespaceTest < ActiveSupport::TestCase
  test "host authentication models inherit engine implementations" do
    assert_operator AdminUser, :<, AnneAuth::AdminUser
    assert_operator CustomerAccount, :<, AnneAuth::Account
    assert_operator CustomerSession, :<, AnneAuth::AccountSession
    assert_operator CustomerAccountIdentity, :<, AnneAuth::AccountIdentity
    assert_operator CustomerAccountVerificationToken, :<, AnneAuth::AccountVerificationToken
    assert_operator CustomerAccountPasswordResetToken, :<, AnneAuth::AccountPasswordResetToken
  end

  test "admin sessions default to the engine model without a host Session wrapper" do
    assert_not Object.const_defined?(:Session, false)
    assert_equal "AnneAuth::AdminSession", AnneAuth.configuration.admin_session_class_name
    assert_equal AnneAuth::AdminSession, AnneAuth.configuration.admin_session_class
    assert_equal "AnneAuth::AdminSession", AnneAuth::AdminUser.reflect_on_association(:sessions).class_name
    assert_equal AnneAuth.configuration.admin_user_class, AnneAuth::AdminSession.reflect_on_association(:admin_user).klass
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
