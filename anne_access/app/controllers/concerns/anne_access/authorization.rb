module AnneAccess
  module Authorization
    extend ActiveSupport::Concern

    included do
      helper_method :current_ability if respond_to?(:helper_method)
    end

    def current_ability
      @current_ability ||= AnneAccess.ability_for(current_access_principal)
    end

    def can_access?(action, resource, record: nil)
      current_ability.can?(action, resource, record:)
    end

    def authorize_access!(action, resource, record: nil)
      return true if can_access?(action, resource, record:)

      raise AnneAccess::NotAuthorizedError, "not authorized to #{action} #{resource}"
    end

    def current_access_principal
      if respond_to?(:current_account, true)
        account = current_account
        return account if account.present?
      end

      if respond_to?(:current_user, true)
        user = current_user
        return user if user.present?
      end

      nil
    end
  end
end
