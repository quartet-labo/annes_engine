module AnneAdmin
  module Authorization
    extend ActiveSupport::Concern

    included do
      helper_method :anne_admin_authorized?
    end

    private
      def authorize_anne_admin!(action, record: nil)
        return if anne_admin_authorized?(action, record:)

        raise AnneAdmin::NotAuthorizedError, "Not authorized to #{action} #{@resource&.name}"
      end

      def anne_admin_authorized?(action, record: nil)
        !!AnneAdmin.configuration.authorized?(anne_admin_authorization_context(action, record:))
      end

      def anne_admin_authorization_context(action, record: nil)
        {
          user: anne_admin_current_user,
          resource: @resource,
          action: action.to_sym,
          record:,
          controller: self
        }
      end
  end
end
