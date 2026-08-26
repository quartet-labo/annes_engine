module AnnesAuth
  class AccountMailer < ::ApplicationMailer
    def verification
      @account = params.fetch(:account)
      @verification_code = params.fetch(:plain_code)
      @verification_expires_in_minutes = AnnesAuth.configuration.account_verification_token_class::DEFAULT_TTL.to_i / 60

      mail(
        to: @account.email,
        subject: "メールアドレス認証のご案内"
      )
    end

    def password_reset
      @account = params.fetch(:account)
      @plain_token = params.fetch(:plain_token)
      @password_reset_url = AnnesAuth.configuration.account_password_reset_url.call(self, @plain_token)

      mail(
        to: @account.email,
        subject: "パスワード再設定のご案内"
      )
    end

    def invitation
      @account = params.fetch(:account)
      plain_token = params.fetch(:plain_token)
      @invitation_url = AnnesAuth.configuration.account_invitation_url.call(self, plain_token)
      @invitation_expires_in_hours =
        AnnesAuth.configuration.account_invitation_token_class::DEFAULT_TTL.to_i / 1.hour.to_i

      mail(
        to: @account.email,
        subject: "アカウント設定のご案内"
      )
    end
  end
end
