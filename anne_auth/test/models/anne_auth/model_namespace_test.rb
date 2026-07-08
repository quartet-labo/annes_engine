require "test_helper"

class AnneAuth::ModelNamespaceTest < ActiveSupport::TestCase
  test "host authentication models inherit engine implementations" do
    assert_operator User, :<, AnneAuth::User
    assert_operator AdminUser, :<, AnneAuth::AdminUser
    assert_operator CustomerAccount, :<, AnneAuth::Account
    assert_operator CustomerSession, :<, AnneAuth::AccountSession
    assert_operator CustomerAccountIdentity, :<, AnneAuth::AccountIdentity
    assert_operator CustomerAccountVerificationToken, :<, AnneAuth::AccountVerificationToken
    assert_operator CustomerAccountPasswordResetToken, :<, AnneAuth::AccountPasswordResetToken
  end

  test "user sessions default to the engine model without a host Session wrapper" do
    assert_not Object.const_defined?(:Session, false)
    assert_equal "User", AnneAuth.configuration.user_class_name
    assert_equal User, AnneAuth.configuration.user_class
    assert_equal "AnneAuth::Session", AnneAuth.configuration.session_class_name
    assert_equal AnneAuth::Session, AnneAuth.configuration.session_class
    assert_equal :user_id, AnneAuth.configuration.session_user_foreign_key
    assert_equal :session_id, AnneAuth.configuration.session_cookie_name
    assert_equal "AnneAuth::Session", User.reflect_on_association(:sessions).class_name
    assert_equal AnneAuth.configuration.user_class, AnneAuth::Session.reflect_on_association(:user).klass
    assert_equal :user_id, AnneAuth::Session.reflect_on_association(:user).foreign_key.to_sym
  end

  test "legacy admin authentication defaults to user session principal" do
    assert_equal "User", AnneAuth.configuration.admin_user_class_name
    assert_equal User, AnneAuth.configuration.admin_user_class
    assert_equal "AnneAuth::Session", AnneAuth.configuration.admin_session_class_name
    assert_equal AnneAuth::Session, AnneAuth.configuration.admin_session_class
    assert_equal :user_id, AnneAuth.configuration.admin_session_user_foreign_key
    assert_equal AnneAuth.configuration.admin_user_class, AnneAuth::Session.reflect_on_association(:admin_user).klass
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
