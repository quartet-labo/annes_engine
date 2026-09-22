module AnnesIntake
  class Configuration
    attr_accessor :endpoints_enabled, :admin_authenticator, :admin_authorizer,
      :definition_authorizer, :operation_token_ttl, :support_path
    attr_reader :adapters
    def initialize
      @endpoints_enabled = false
      @adapters = {}
      @operation_token_ttl = 2.hours
    end
  end
end
