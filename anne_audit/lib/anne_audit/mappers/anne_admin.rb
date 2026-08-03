module AnneAudit
  module Mappers
    class AnneAdmin
      class << self
        def call(event)
          payload = event.payload.symbolize_keys

          {
            source: "anne_admin",
            action: payload[:action],
            result: payload[:result] || payload[:status] || "success",
            occurred_at: event_time(event),
            actor: actor_reference(payload),
            target: target_reference(payload),
            metadata: metadata(event, payload)
          }
        end

        private
          def actor_reference(payload)
            {
              type: payload[:actor_type] || payload[:user_type],
              id: payload[:actor_id] || payload[:user_id],
              label: payload[:actor_label] || payload[:user_label] || payload[:user_id]
            }.compact
          end

          def target_reference(payload)
            {
              type: payload[:target_type] || payload[:record_type] || payload[:resource],
              id: payload[:target_id] || payload[:record_id],
              label: payload[:target_label] || payload[:record_label]
            }.compact
          end

          def metadata(event, payload)
            payload.except(
              :action,
              :result,
              :status,
              :actor_type,
              :actor_id,
              :actor_label,
              :user_type,
              :user_id,
              :user_label,
              :target_type,
              :target_id,
              :target_label,
              :record_type,
              :record_id,
              :record_label
            ).merge(duration_ms: event.duration)
          end

          def event_time(event)
            Time.zone ? Time.zone.at(event.time) : Time.at(event.time)
          end
      end
    end
  end
end
