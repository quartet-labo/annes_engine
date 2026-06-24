module CustomerAuthentication
  extend ActiveSupport::Concern

  include AnneAuth::AccountAuthentication

  included do
    helper_method :customer_authenticated?, :customer_profile_complete?, :current_customer_account
  end

  private
    def customer_authenticated?
      account_authenticated?
    end

    def customer_profile_complete?
      account_profile_complete?
    end

    def current_customer_account
      current_account
    end

    def current_customer_session
      current_account_session
    end

    def require_customer_authentication
      require_account_authentication
    end

    def require_verified_customer_account
      require_verified_account
    end

    def after_customer_authentication_url
      after_account_authentication_url
    end

    def after_customer_profile_completion_url
      after_account_profile_completion_url
    end

    def start_new_customer_session_for(customer_account)
      start_new_account_session_for(customer_account)
    end

    def terminate_customer_session
      terminate_account_session
    end
end
