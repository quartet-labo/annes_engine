module AnnesInquiry
  class Configuration
    attr_accessor :public_endpoints_enabled, :admin_authenticator, :admin_authorizer, :admin_home_path, :admin_submission_link, :admin_notification_action, :retention_days
    attr_reader :adapters

    def initialize
      @public_endpoints_enabled = false
      @adapters = {}
    end
  end
end
