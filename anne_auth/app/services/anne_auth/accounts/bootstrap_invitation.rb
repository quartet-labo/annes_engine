module AnneAuth
  module Accounts
    class BootstrapInvitation
      Result = Data.define(:status, :account) do
        def success?
          status == :delivered
        end
      end

      MAX_CLAIM_RETRIES = 3

      def self.call(email:)
        new(email:).call
      end

      def initialize(email:)
        @email = email
      end

      def call
        existing_account = first_active_account
        return Result.new(:already_bootstrapped, existing_account) if existing_account && bootstrap_claim.blank?

        claim, account, status = prepare_bootstrap_account
        return Result.new(status, account) unless status == :ready_to_deliver

        delivery_result = AnneAuth::Accounts::InvitationDelivery.call(account)
        record_delivery_status(claim, delivery_result.status)

        Result.new(delivery_result.status, account)
      end

      private
        attr_reader :email

        def prepare_bootstrap_account
          with_bootstrap_claim_lock do |claim|
            if claim.completed_at.present?
              [ claim, claim_account(claim) || first_active_account, :already_bootstrapped ]
            elsif claim.account_id.present?
              account = claim_account(claim)
              if pending_bootstrap_account?(account)
                [ claim, account, :ready_to_deliver ]
              else
                [ claim, nil, :invalid_account ]
              end
            elsif (account = first_active_account)
              [ claim, account, :already_bootstrapped ]
            else
              account = build_bootstrap_account
              if account.save
                claim.update!(
                  account_class_name: account.class.name,
                  account_id: account.id,
                  last_delivery_status: nil,
                  completed_at: nil
                )
                AnneAuth.configuration.account_bootstrapped(account)

                [ claim, account, :ready_to_deliver ]
              else
                claim.destroy!
                [ claim, nil, :invalid_account ]
              end
            end
          end
        end

        def with_bootstrap_claim_lock
          attempts = 0

          begin
            bootstrap_claim_class.transaction do
              claim = bootstrap_claim_class.lock.find_by(purpose: AnneAuth::BootstrapClaim::INITIAL_ACCOUNT_PURPOSE)
              claim ||= bootstrap_claim_class.create!(purpose: AnneAuth::BootstrapClaim::INITIAL_ACCOUNT_PURPOSE)
              claim.lock!

              yield claim
            end
          rescue ActiveRecord::RecordNotUnique
            attempts += 1
            retry if attempts < MAX_CLAIM_RETRIES

            raise
          end
        end

        def build_bootstrap_account
          password = SecureRandom.urlsafe_base64(32)
          account_class.new(
            email:,
            password:,
            password_confirmation: password
          )
        end

        def record_delivery_status(claim, status)
          claim.with_lock do
            attributes = { last_delivery_status: status.to_s }
            attributes[:completed_at] = Time.current if status == :delivered
            claim.update!(attributes)
          end
        end

        def bootstrap_claim
          @bootstrap_claim ||= bootstrap_claim_class.find_by(purpose: AnneAuth::BootstrapClaim::INITIAL_ACCOUNT_PURPOSE)
        end

        def claim_account(claim)
          return if claim.account_class_name.blank? || claim.account_id.blank?

          claim.account_class_name.constantize.find_by(id: claim.account_id)
        rescue NameError
          nil
        end

        def pending_bootstrap_account?(account)
          account&.persisted? && !account.disabled? && !account.email_verified?
        end

        def first_active_account
          account_class.active.order(:id).first
        end

        def account_class
          AnneAuth.configuration.account_class
        end

        def bootstrap_claim_class
          AnneAuth::BootstrapClaim
        end
    end
  end
end
