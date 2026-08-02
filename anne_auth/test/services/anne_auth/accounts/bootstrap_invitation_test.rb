require "test_helper"

class AnneAuth::Accounts::BootstrapInvitationTest < ActiveSupport::TestCase
  class RecordingBootstrapMailer
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
      raise DeliveryError, "delivery failed" if self.class.fail_delivery

      true
    end
  end

  setup do
    @original_account_mailer_class_name = AnneAuth.configuration.account_mailer_class_name
    @original_after_account_bootstrapped = AnneAuth.configuration.after_account_bootstrapped
    AnneAuth.configuration.account_mailer_class_name =
      "AnneAuth::Accounts::BootstrapInvitationTest::RecordingBootstrapMailer"
    AnneAuth.configuration.after_account_bootstrapped = ->(_account) {}
    RecordingBootstrapMailer.reset!
    clear_bootstrap_records!
  end

  teardown do
    AnneAuth.configuration.account_mailer_class_name = @original_account_mailer_class_name
    AnneAuth.configuration.after_account_bootstrapped = @original_after_account_bootstrapped
    RecordingBootstrapMailer.reset!
  end

  test "creates an unverified account and sends an invitation when no active account exists" do
    result = AnneAuth::Accounts::BootstrapInvitation.call(email: "initial@example.com")

    assert_equal :delivered, result.status
    assert result.success?
    assert_instance_of CustomerAccount, result.account
    assert_equal "initial@example.com", result.account.email
    assert_not result.account.email_verified?
    assert_not_empty result.account.password_digest

    assert_equal 1, RecordingBootstrapMailer.deliveries.size
    delivery = RecordingBootstrapMailer.deliveries.first
    assert_equal result.account, delivery.fetch(:account)
    plain_token = delivery.fetch(:plain_token)
    assert CustomerAccountInvitationToken.lookup(plain_token).success?

    claim = AnneAuth::BootstrapClaim.find_by!(purpose: AnneAuth::BootstrapClaim::INITIAL_ACCOUNT_PURPOSE)
    assert_equal result.account.class.name, claim.account_class_name
    assert_equal result.account.id, claim.account_id
    assert_equal "delivered", claim.last_delivery_status
    assert_not_nil claim.completed_at
  end

  test "does not create a bootstrap account when an active account already exists" do
    existing = CustomerAccount.create!(
      email: "existing@example.com",
      password: "password-123",
      password_confirmation: "password-123"
    )

    result = AnneAuth::Accounts::BootstrapInvitation.call(email: "initial@example.com")

    assert_equal :already_bootstrapped, result.status
    assert_equal existing, result.account
    assert_equal [ existing ], CustomerAccount.all.to_a
    assert_empty RecordingBootstrapMailer.deliveries
    assert_empty AnneAuth::BootstrapClaim.all
  end

  test "returns invalid account without leaving bootstrap records" do
    result = AnneAuth::Accounts::BootstrapInvitation.call(email: "invalid-email")

    assert_equal :invalid_account, result.status
    assert_nil result.account
    assert_empty CustomerAccount.all
    assert_empty AnneAuth::BootstrapClaim.all
    assert_empty RecordingBootstrapMailer.deliveries
  end

  test "retries invitation delivery for the same bootstrap account after delivery failure" do
    RecordingBootstrapMailer.fail_delivery = true

    failed_result = AnneAuth::Accounts::BootstrapInvitation.call(email: "initial@example.com")
    failed_plain_token = RecordingBootstrapMailer.deliveries.first.fetch(:plain_token)

    assert_equal :delivery_failed, failed_result.status
    assert_equal 1, CustomerAccount.count
    claim = AnneAuth::BootstrapClaim.find_by!(purpose: AnneAuth::BootstrapClaim::INITIAL_ACCOUNT_PURPOSE)
    assert_equal failed_result.account.id, claim.account_id
    assert_equal "delivery_failed", claim.last_delivery_status
    assert_nil claim.completed_at

    RecordingBootstrapMailer.fail_delivery = false
    retry_result = AnneAuth::Accounts::BootstrapInvitation.call(email: "initial@example.com")
    retry_plain_token = RecordingBootstrapMailer.deliveries.last.fetch(:plain_token)

    assert_equal :delivered, retry_result.status
    assert_equal failed_result.account, retry_result.account
    assert_equal 1, CustomerAccount.count
    assert_equal :used, CustomerAccountInvitationToken.lookup(failed_plain_token).status
    assert CustomerAccountInvitationToken.lookup(retry_plain_token).success?
    assert_equal "delivered", claim.reload.last_delivery_status
    assert_not_nil claim.completed_at
  end

  test "rolls back the account and claim when the host bootstrap hook fails" do
    AnneAuth.configuration.after_account_bootstrapped = ->(_account) { raise "role assignment failed" }

    error = assert_raises(RuntimeError) do
      AnneAuth::Accounts::BootstrapInvitation.call(email: "initial@example.com")
    end

    assert_equal "role assignment failed", error.message
    assert_empty CustomerAccount.all
    assert_empty AnneAuth::BootstrapClaim.all
    assert_empty RecordingBootstrapMailer.deliveries
  end

  test "concurrent bootstrap creates only one initial account" do
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          results << AnneAuth::Accounts::BootstrapInvitation.call(email: "initial-#{index}@example.com")
        rescue StandardError => error
          results << error
        end
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)

    outcomes = 2.times.map { results.pop }
    assert_empty outcomes.grep(Exception)
    assert_equal 1, CustomerAccount.count
    assert_equal 1, AnneAuth::BootstrapClaim.count
    assert outcomes.any?(&:success?)
    assert outcomes.all? { |result| %i[delivered already_bootstrapped].include?(result.status) }
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end

  private
    def clear_bootstrap_records!
      CustomerAccountProject.delete_all
      CustomerAccountMembership.delete_all
      CustomerSession.delete_all
      CustomerAccountIdentity.delete_all
      CustomerAccountVerificationToken.delete_all
      CustomerAccountPasswordResetToken.delete_all
      CustomerAccountInvitationToken.delete_all
      CustomerAccount.delete_all
      AnneAuth::BootstrapClaim.delete_all
    end
end
