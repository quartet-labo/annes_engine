module AnneAdmin
  module Authorization
    extend ActiveSupport::Concern

    private
      def authorize_anne_admin!(action, record: nil)
        context = {
          user: anne_admin_current_user,
          resource: @resource,
          action: action.to_sym,
          record:,
          controller: self
        }
        return if AnneAdmin.configuration.authorized?(context)

        raise AnneAdmin::NotAuthorizedError, "Not authorized to #{action} #{@resource&.name}"
      end
  end
end
