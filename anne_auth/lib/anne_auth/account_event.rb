require "active_support/notifications"

module AnneAuth
  class AccountEvent
    EVENT_NAME = "anne_auth.account_event".freeze
    SENSITIVE_METADATA_KEY_PATTERN = /password|token|code|otp|cookie|secret|credential/i

    def self.emit(event, account: nil, account_session: nil, request: nil, auth_method: nil, provider: nil, status: :success, metadata: {})
      ActiveSupport::Notifications.instrument(
        EVENT_NAME,
        event: event.to_s,
        account_id: account&.to_param,
        account_class: account&.class&.name,
        account_email: account&.email,
        session_id: account_session&.to_param,
        auth_method: auth_method&.to_s,
        provider: provider&.to_s,
        ip_address: request&.remote_ip,
        user_agent: request&.user_agent,
        status: status.to_s,
        metadata: normalize_metadata(metadata)
      )
    end

    def self.normalize_metadata(metadata)
      return {} unless metadata.respond_to?(:to_h)

      metadata.to_h.each_with_object({}) do |(key, value), filtered|
        next if sensitive_metadata_key?(key)

        filtered[key.to_sym] = normalize_metadata_value(value)
      end
    end
    private_class_method :normalize_metadata

    def self.normalize_metadata_value(value)
      case value
      when Symbol
        value.to_s
      when Hash
        normalize_metadata(value)
      when Array
        value.map { |item| normalize_metadata_value(item) }
      else
        value
      end
    end
    private_class_method :normalize_metadata_value

    def self.sensitive_metadata_key?(key)
      key.to_s.match?(SENSITIVE_METADATA_KEY_PATTERN)
    end
    private_class_method :sensitive_metadata_key?
  end
end
