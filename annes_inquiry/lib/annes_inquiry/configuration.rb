module AnnesInquiry
  class Configuration
    attr_accessor :public_endpoints_enabled, :admin_authenticator, :admin_authorizer, :admin_home_path, :admin_submission_link, :admin_notification_action, :retention_days
    attr_accessor :flow_endpoints_enabled
    attr_reader :adapters, :flow_adapters

    def initialize
      @public_endpoints_enabled = false
      @adapters = {}
      @flow_adapters = {}
      @flow_endpoints_enabled = false
    end
  end
end
