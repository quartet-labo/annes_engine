require "action_controller"

module AnnesAuth
  class OmniauthTokenVerifier
    def self.config
      ActionController::Base.config
    end

    include ActionController::RequestForgeryProtection

    ActionController::Base.config.each_key do |configuration_name|
      define_method(configuration_name) do
        ActionController::Base.config[configuration_name]
      end
    end

    def call(env)
      dup._call(env)
    end

    def _call(env)
      @request = ActionDispatch::Request.new(env.dup)

      raise ActionController::InvalidAuthenticityToken unless verified_request?
    end

    private
      attr_reader :request
      delegate :params, :session, to: :request
  end
end
