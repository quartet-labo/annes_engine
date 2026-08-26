module AnnesAudit
  module Mappers
    class AnnesAuth
      class << self
        def call(event)
          payload = event.payload.symbolize_keys

          {
            source: "annes_auth",
            action: payload[:event],
            result: payload[:status] || "success",
            occurred_at: event_time(event),
            actor: account_reference(payload),
            target: account_reference(payload),
            ip_address: payload[:ip_address],
            user_agent: payload[:user_agent],
            metadata: metadata(event, payload)
          }
        end

        private
          def account_reference(payload)
            {
              type: payload[:account_class],
              id: payload[:account_id],
              label: payload[:account_email]
            }.compact
          end

          def metadata(event, payload)
            payload.except(
              :event,
              :status,
              :account_class,
              :account_id,
              :account_email,
              :ip_address,
              :user_agent
            ).merge(duration_ms: event.duration)
          end

          def event_time(event)
            Time.zone ? Time.zone.at(event.time) : Time.at(event.time)
          end
      end
    end
  end
end
