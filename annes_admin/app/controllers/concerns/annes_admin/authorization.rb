module AnnesAdmin
  module Authorization
    extend ActiveSupport::Concern

    included do
      helper_method :annes_admin_authorized?
    end

    private
      def authorize_annes_admin!(action, record: nil)
        return if annes_admin_authorization_allowed?(action, record:)

        raise AnnesAdmin::NotAuthorizedError, "Not authorized to #{action} #{@resource&.name}"
      end

      def annes_admin_authorized?(action, record: nil)
        annes_admin_authorization_allowed?(action, record:)
      end

      def annes_admin_authorization_allowed?(action, record: nil)
        !!AnnesAdmin.configuration.authorized?(annes_admin_authorization_context(action, record:))
      end

      def annes_admin_authorization_context(action, record: nil)
        {
          user: annes_admin_current_user,
          resource: @resource,
          action: action.to_sym,
          record:,
          controller: self
        }
      end
  end
end
