require "test_helper"

class AnneAuth::Accounts::InvitationDeliveryTest < ActiveSupport::TestCase
  class RecordingInvitationMailer
    class DeliveryError < StandardError; end

    class << self
      attr_accessor :deliveries, :fail_delivery

      def with(params)
        new(params)
      end

      def reset!
        self.deliveries = []
        self.fail_delivery = false
      end
    end

    def initialize(params)
      @params = params
    end

    def invitation
      self
    end

    def deliver_now
      self.class.deliveries << @params
      raise DeliveryError, "delivery failed for #{@params.fetch(:plain_token)}" if self.class.fail_delivery

      true
    end
  end

  setup do
    @account = customer_accounts(:unverified)
    @account.update!(email_verified_at: nil, disabled_at: nil)
    @account.account_invitation_tokens.destroy_all
    @original_account_mailer_class_name = AnneAuth.configuration.account_mailer_class_name
    @original_logger = Rails.logger
    @log_output = StringIO.new
    Rails.logger = ActiveSupport::Logger.new(@log_output)
    AnneAuth.configuration.account_mailer_class_name =
      "AnneAuth::Accounts::InvitationDeliveryTest::RecordingInvitationMailer"
    RecordingInvitationMailer.reset!
  end

  teardown do
    AnneAuth.configuration.account_mailer_class_name = @original_account_mailer_class_name
    Rails.logger = @original_logger
    RecordingInvitationMailer.reset!
  end

  test "synchronously delivers an invitation for an eligible account" do
    result = AnneAuth::Accounts::InvitationDelivery.call(@account)

    assert_equal :delivered, result.status
    assert result.success?
    assert_equal [ :status ], result.members
    assert_equal 1, RecordingInvitationMailer.deliveries.size

    delivery = RecordingInvitationMailer.deliveries.first
    assert_equal @account, delivery.fetch(:account)
    plain_token = delivery.fetch(:plain_token)
    assert_match CustomerAccountInvitationToken::TOKEN_FORMAT, plain_token
    assert CustomerAccountInvitationToken.lookup(plain_token).success?
    assert_not_includes result.inspect, plain_token
  end

  test "rejects unpersisted disabled and verified accounts without issuing or delivering" do
    unpersisted_account = CustomerAccount.new(
      email: "not-persisted@example.com",
      password: "password-123"
    )
    disabled_account = @account
    disabled_account.update!(disabled_at: Time.current)
    verified_account = customer_accounts(:verified)
    verified_account.account_invitation_tokens.destroy_all

    [ unpersisted_account, disabled_account, verified_account ].each do |account|
      result = AnneAuth::Accounts::InvitationDelivery.call(account)

      assert_equal :invalid_account, result.status
    end

    assert_empty RecordingInvitationMailer.deliveries
    assert_empty disabled_account.account_invitation_tokens.reload
    assert_empty verified_account.account_invitation_tokens.reload
  end

  test "resending invalidates the previously delivered invitation" do
    first_result = AnneAuth::Accounts::InvitationDelivery.call(@account)
    first_plain_token = RecordingInvitationMailer.deliveries.last.fetch(:plain_token)

    second_result = AnneAuth::Accounts::InvitationDelivery.call(@account)
    second_plain_token = RecordingInvitationMailer.deliveries.last.fetch(:plain_token)

    assert_equal :delivered, first_result.status
    assert_equal :delivered, second_result.status
    assert_not_equal first_plain_token, second_plain_token
    assert_equal :used, CustomerAccountInvitationToken.lookup(first_plain_token).status
    assert CustomerAccountInvitationToken.lookup(second_plain_token).success?
  end

  test "reports delivery failures without exposing the plain token" do
    RecordingInvitationMailer.fail_delivery = true

    result = AnneAuth::Accounts::InvitationDelivery.call(@account)
    plain_token = RecordingInvitationMailer.deliveries.first.fetch(:plain_token)

    assert_equal :delivery_failed, result.status
    assert_not result.success?
    assert_not_includes result.inspect, plain_token
    assert_not_includes @log_output.string, plain_token
    assert_match "DeliveryError", @log_output.string

    RecordingInvitationMailer.fail_delivery = false
    retry_result = AnneAuth::Accounts::InvitationDelivery.call(@account)
    retry_plain_token = RecordingInvitationMailer.deliveries.last.fetch(:plain_token)

    assert_equal :delivered, retry_result.status
    assert_equal :used, CustomerAccountInvitationToken.lookup(plain_token).status
    assert CustomerAccountInvitationToken.lookup(retry_plain_token).success?
  end
end
