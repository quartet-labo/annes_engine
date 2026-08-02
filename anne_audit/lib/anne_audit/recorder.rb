module AnneAudit
  class Recorder
    def self.call(**attributes)
      new(**attributes).call
    end

    def initialize(source:, action:, actor: nil, target: nil, result: :success, request: nil, occurred_at: nil, metadata: {}, event_id: nil, request_id: nil, ip_address: nil, user_agent: nil)
      @source = source
      @action = action
      @actor = actor
      @target = target
      @result = result
      @request = request
      @occurred_at = occurred_at
      @metadata = metadata
      @event_id = event_id
      @request_id = request_id
      @ip_address = ip_address
      @user_agent = user_agent
    end

    def call
      Event.create!(event_attributes)
    end

    private
      attr_reader :source, :action, :actor, :target, :result, :request, :occurred_at, :metadata, :event_id, :request_id, :ip_address, :user_agent

      def event_attributes
        actor_reference = Reference.normalize(actor || context[:actor])
        target_reference = Reference.normalize(target)
        request_object = request || context[:request]

        {
          event_id: event_id&.to_s,
          source: source.to_s,
          action: action.to_s,
          result: result.to_s,
          occurred_at: occurred_at,
          actor_type: actor_reference[:type],
          actor_id: actor_reference[:id],
          actor_label: actor_reference[:label],
          target_type: target_reference[:type],
          target_id: target_reference[:id],
          target_label: target_reference[:label],
          request_id: request_id || request_value(request_object, :request_id),
          ip_address: ip_address || request_value(request_object, :remote_ip),
          user_agent: user_agent || request_value(request_object, :user_agent),
          metadata: MetadataFilter.new.call(metadata || {})
        }.compact
      end

      def context
        Context.current
      end

      def request_value(request_object, method_name)
        return nil unless request_object&.respond_to?(method_name)

        request_object.public_send(method_name)
      end
  end
end
