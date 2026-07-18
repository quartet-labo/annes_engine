require "test_helper"

class AnneAuth::AccountInvitationTokenTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @account = customer_accounts(:unverified)
    reset_account!(@account, email_verified_at: nil, disabled_at: nil)
    invitation_token_class.delete_all
  end

  teardown do
    invitation_token_class.delete_all if defined?(CustomerAccountInvitationToken)
    reset_account!(@account, email_verified_at: nil, disabled_at: nil) if @account&.persisted?
  end

  test "issues a one hour invitation backed only by a SHA-256 digest" do
    travel_to Time.zone.local(2026, 7, 18, 12, 0, 0) do
      invitation, plain_token = invitation_token_class.issue_for(@account)

      assert_match invitation_token_class::TOKEN_FORMAT, plain_token
      assert_equal invitation_token_class.digest(plain_token), invitation.token_digest
      assert_equal 64, invitation.token_digest.length
      assert_not_equal plain_token, invitation.token_digest
      assert_not_includes invitation.attributes.values, plain_token
      assert_equal 1.hour.from_now, invitation.expires_at

      lookup = invitation_token_class.lookup(plain_token)
      assert lookup.success?
      assert_equal invitation, lookup.invitation_token
    end
  end

  test "reports invalid used expired disabled and verified invitations" do
    assert_equal :invalid, invitation_token_class.lookup("not a token").status

    used_invitation, used_plain_token = invitation_token_class.issue_for(@account)
    used_invitation.mark_used!
    assert_equal :used, invitation_token_class.lookup(used_plain_token).status

    expired_invitation, expired_plain_token = invitation_token_class.issue_for(
      @account,
      expires_at: 1.second.ago
    )
    assert expired_invitation.expired?
    assert_equal :expired, invitation_token_class.lookup(expired_plain_token).status

    disabled_invitation, disabled_plain_token = invitation_token_class.issue_for(@account)
    @account.update!(disabled_at: Time.current)
    assert_equal :disabled_account, invitation_token_class.lookup(disabled_plain_token).status
    assert_not invitation_token_class.lookup(disabled_plain_token).success?
    assert_not disabled_invitation.reload.used?

    reset_account!(@account, disabled_at: nil, email_verified_at: nil)
    verified_invitation, verified_plain_token = invitation_token_class.issue_for(@account)
    @account.update!(email_verified_at: Time.current)
    assert_equal :verified_account, invitation_token_class.lookup(verified_plain_token).status
    assert_not invitation_token_class.lookup(verified_plain_token).success?

    assert used_invitation.reload.used?
    assert expired_invitation.reload.expired?
    assert_not verified_invitation.reload.used?
  end

  test "reissuing expires the previous unconsumed invitation" do
    old_invitation, old_plain_token = invitation_token_class.issue_for(@account)
    new_invitation, new_plain_token = invitation_token_class.issue_for(@account)

    assert old_invitation.reload.used?
    assert_not new_invitation.reload.used?
    assert_equal :used, invitation_token_class.lookup(old_plain_token).status
    assert invitation_token_class.lookup(new_plain_token).success?
    assert_equal 1, @account.account_invitation_tokens.where(used_at: nil).count
  end

  test "refuses to issue for unpersisted disabled or verified accounts" do
    unpersisted_account = CustomerAccount.new(
      email: "pending-invitation@example.com",
      password: "password-123",
      password_confirmation: "password-123"
    )

    assert_raises(AnneAuth::AccountInvitationToken::InvalidAccountError) do
      invitation_token_class.issue_for(unpersisted_account)
    end

    @account.update!(disabled_at: Time.current)
    assert_raises(AnneAuth::AccountInvitationToken::InvalidAccountError) do
      invitation_token_class.issue_for(@account)
    end

    reset_account!(@account, disabled_at: nil, email_verified_at: Time.current)
    assert_raises(AnneAuth::AccountInvitationToken::InvalidAccountError) do
      invitation_token_class.issue_for(@account)
    end

    assert_empty invitation_token_class.all
  end

  test "concurrent issuance leaves only one usable invitation" do
    account_id = @account.id
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          account = CustomerAccount.find(account_id)
          ready << true
          start.pop
          results << invitation_token_class.issue_for(account)
        rescue StandardError => error
          results << error
        end
      end
    end

    2.times { ready.pop }
    2.times { start << true }
    threads.each(&:join)

    issued = 2.times.map { results.pop }
    errors = issued.grep(Exception)

    assert_empty errors
    assert_equal 2, issued.length
    foreign_key = AnneAuth.configuration.account_foreign_key
    assert_equal 1, invitation_token_class.where(foreign_key => account_id, used_at: nil).count
    assert_equal 1, issued.count { |invitation, token| invitation_token_class.lookup(token).success? }
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end

  private
    def invitation_token_class
      CustomerAccountInvitationToken
    end

    def reset_account!(account, email_verified_at:, disabled_at:)
      account.update_columns(email_verified_at:, disabled_at:, updated_at: Time.current)
      account.reload
    end
end
