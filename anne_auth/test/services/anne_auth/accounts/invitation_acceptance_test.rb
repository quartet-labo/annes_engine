require "test_helper"

class AnneAuth::Accounts::InvitationAcceptanceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @account = CustomerAccount.find_by!(email: "unverified@example.com")
    reset_account!
    clear_account_credentials!
  end

  teardown do
    clear_account_credentials! if @account&.persisted?
    reset_account! if @account&.persisted?
  end

  test "invalid password keeps the invitation reusable" do
    invitation, = CustomerAccountInvitationToken.issue_for(@account)

    result = accept(invitation, password: "short", password_confirmation: "short")

    assert_equal :invalid_password, result.status
    assert_equal @account, result.account
    assert result.account.errors[:password].present?
    assert_not invitation.reload.used?
    assert_not @account.reload.email_verified?
    assert @account.authenticate("password-123")

    retry_result = accept(
      invitation,
      password: "new-password-123",
      password_confirmation: "new-password-123"
    )

    assert retry_result.success?
    assert invitation.reload.used?
    assert @account.reload.email_verified?
    assert @account.authenticate("new-password-123")
  end

  test "successful acceptance invalidates all account credentials" do
    invitation, = CustomerAccountInvitationToken.issue_for(@account)
    extra_invitation = @account.account_invitation_tokens.create!(
      token_digest: CustomerAccountInvitationToken.digest("extra-invitation-token"),
      expires_at: 1.hour.from_now
    )
    password_reset, = CustomerAccountPasswordResetToken.issue_for(@account)
    verification_token, = CustomerAccountVerificationToken.issue_for(@account)
    sessions = 2.times.map do |index|
      @account.account_sessions.create!(
        user_agent: "test-agent-#{index}",
        ip_address: "127.0.0.1",
        expires_at: 1.day.from_now,
        last_used_at: Time.current
      )
    end

    result = accept(
      invitation,
      password: "new-password-123",
      password_confirmation: "new-password-123"
    )

    assert result.success?
    assert @account.reload.email_verified?
    assert @account.authenticate("new-password-123")
    assert invitation.reload.used?
    assert extra_invitation.reload.used?
    assert password_reset.reload.used?
    assert verification_token.reload.used?
    assert_empty @account.account_sessions.reload
    assert sessions.none? { |account_session| CustomerSession.exists?(account_session.id) }
  end

  test "missing used disabled and verified invitations are rejected without mutation" do
    assert_equal :invalid, accept(nil).status

    used_invitation, = CustomerAccountInvitationToken.issue_for(@account)
    used_invitation.mark_used!
    assert_equal :invalid, accept(used_invitation).status

    disabled_invitation, = CustomerAccountInvitationToken.issue_for(@account)
    @account.update!(disabled_at: Time.current)
    assert_equal :invalid, accept(disabled_invitation).status
    assert_not disabled_invitation.reload.used?

    @account.update!(disabled_at: nil, email_verified_at: nil)
    verified_invitation, = CustomerAccountInvitationToken.issue_for(@account)
    @account.update!(email_verified_at: Time.current)
    assert_equal :invalid, accept(verified_invitation).status
    assert_not verified_invitation.reload.used?
  end

  test "concurrent acceptance succeeds only once" do
    invitation, = CustomerAccountInvitationToken.issue_for(@account)
    invitation_id = invitation.id
    ready = Queue.new
    start = Queue.new
    results = Queue.new

    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          thread_invitation = CustomerAccountInvitationToken.find(invitation_id)
          ready << true
          start.pop
          results << accept(
            thread_invitation,
            password: "new-password-123",
            password_confirmation: "new-password-123"
          )
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
    assert_equal 1, outcomes.count(&:success?)
    assert_equal 1, outcomes.count { |result| result.status == :invalid }
    assert invitation.reload.used?
    assert @account.reload.email_verified?
    assert @account.authenticate("new-password-123")
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end

  private
    def accept(invitation, password: "new-password-123", password_confirmation: "new-password-123")
      AnneAuth::Accounts::InvitationAcceptance.call(
        invitation_token: invitation,
        password:,
        password_confirmation:
      )
    end

    def clear_account_credentials!
      @account.account_invitation_tokens.delete_all
      @account.account_password_reset_tokens.delete_all
      @account.account_verification_tokens.delete_all
      @account.account_sessions.delete_all
    end

    def reset_account!
      @account.update_columns(
        password_digest: BCrypt::Password.create("password-123"),
        email_verified_at: nil,
        disabled_at: nil,
        updated_at: Time.current
      )
      @account.reload
    end
end
