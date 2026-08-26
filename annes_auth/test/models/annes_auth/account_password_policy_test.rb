require "test_helper"

class AnnesAuth::AccountPasswordPolicyTest < ActiveSupport::TestCase
  setup do
    @original_minimum_length = AnnesAuth.configuration.account_password_minimum_length
  end

  teardown do
    AnnesAuth.configuration.account_password_minimum_length = @original_minimum_length
  end

  test "requires password to meet the configured minimum length" do
    account = CustomerAccount.new(
      email: "short-password@example.com",
      password: "short",
      password_confirmation: "short"
    )

    assert_not account.valid?
    assert_not_empty account.errors[:password]
  end

  test "accepts passwords at the configured minimum length" do
    account = CustomerAccount.new(
      email: "valid-password@example.com",
      password: "password-123",
      password_confirmation: "password-123"
    )

    assert account.valid?
  end

  test "uses configured minimum length" do
    AnnesAuth.configuration.account_password_minimum_length = 16
    account = CustomerAccount.new(
      email: "configured-password@example.com",
      password: "password-123",
      password_confirmation: "password-123"
    )

    assert_not account.valid?
    assert_not_empty account.errors[:password]
  end
end
