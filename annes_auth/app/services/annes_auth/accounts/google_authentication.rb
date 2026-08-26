module AnnesAuth
  module Accounts
    class GoogleAuthentication
      PROVIDER = "google"
      OMNIAUTH_PROVIDER = "google_oauth2"

      Result = Data.define(:status, :account, :identity, :profile_name) do
        def success?
          status == :ok
        end

        def profile_required?
          success? && !AnnesAuth.configuration.profile_complete?(account)
        end
      end

      def self.call(auth_hash)
        new(auth_hash).call
      end

      def initialize(auth_hash)
        @auth = (auth_hash || {}).to_h.deep_stringify_keys
      end

      def call
        return failure(:invalid_provider) unless provider == OMNIAUTH_PROVIDER
        return failure(:missing_uid) if uid.blank?
        return failure(:missing_email) if email.blank?
        return failure(:unverified_email) unless email_verified?

        if (identity = identity_class.includes(:account).find_by(provider: PROVIDER, uid:))
          return failure(:disabled_account) if identity.account.disabled?

          identity.update!(email:)
          identity.account.verify_email! unless identity.account.email_verified?
          return success(identity.account, identity)
        end

        account = account_class.find_by(email:)
        return create_account if account.blank?
        return failure(:disabled_account) if account.disabled?

        link_existing_account(account)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        failure(:invalid)
      end

      private
        attr_reader :auth

        def account_class
          AnnesAuth.configuration.account_class
        end

        def identity_class
          AnnesAuth.configuration.account_identity_class
        end

        def provider
          auth["provider"].to_s
        end

        def uid
          @uid ||= auth["uid"].presence || auth.dig("extra", "id_info", "sub").to_s.presence
        end

        def email
          @email ||= begin
            raw_email = auth.dig("info", "email").presence || auth.dig("extra", "id_info", "email").presence
            raw_email.to_s.strip.downcase.presence
          end
        end

        def profile_name
          @profile_name ||= auth.dig("info", "name").presence || auth.dig("extra", "id_info", "name").presence
        end

        def email_verified?
          value = auth.dig("info", "email_verified")
          value = auth.dig("extra", "id_info", "email_verified") if value.nil?

          value == true || value.to_s == "true"
        end

        def link_existing_account(account)
          existing_provider_identity = account.account_identities.find_by(provider: PROVIDER)
          return failure(:identity_conflict) if existing_provider_identity.present?

          account_class.transaction do
            account.verify_email! unless account.email_verified?
            identity = account.account_identities.create!(provider: PROVIDER, uid:, email:)

            success(account, identity)
          end
        end

        def create_account
          account_class.transaction do
            password = SecureRandom.urlsafe_base64(32)
            account = account_class.create!(
              email:,
              password:,
              password_confirmation: password,
              email_verified_at: Time.current
            )
            identity = account.account_identities.create!(provider: PROVIDER, uid:, email:)

            success(account, identity)
          end
        end

        def success(account, identity)
          Result.new(:ok, account, identity, profile_name)
        end

        def failure(status)
          Result.new(status, nil, nil, nil)
        end
    end
  end
end
