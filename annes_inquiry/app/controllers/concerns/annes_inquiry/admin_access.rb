module AnnesInquiry
  module AdminAccess
    extend ActiveSupport::Concern

    included do
      before_action :require_inquiry_administration
      helper AnnesInquiry::FormHelper
      layout "annes_inquiry/admin"
    end

    private
      def require_inquiry_administration
        config = AnnesInquiry.configuration
        user = config.admin_authenticator&.call(self)
        return if performed?
        head :forbidden unless user && config.admin_authorizer&.call(self, user)
      end
  end
end
