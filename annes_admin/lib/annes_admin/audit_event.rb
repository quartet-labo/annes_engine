module AnnesAdmin
  class AuditEvent
    EVENT_NAME = "annes_admin.audit".freeze

    def self.emit(resource:, action:, record:, user:, status:)
      ActiveSupport::Notifications.instrument(
        EVENT_NAME,
        resource: resource.name,
        action: action.to_s,
        record_id: record&.to_param,
        user_id: user_identifier(user),
        status: status.to_s
      )
    end

    def self.user_identifier(user)
      return nil if user.blank?
      return user.id if user.respond_to?(:id)
      return user.email if user.respond_to?(:email)

      user.to_s
    end
  end
end
