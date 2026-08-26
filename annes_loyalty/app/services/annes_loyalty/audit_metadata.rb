module AnnesLoyalty
  class AuditMetadata
    def self.build(actor: nil, metadata: {})
      new(actor:, metadata:).call
    end

    def initialize(actor:, metadata:)
      @actor = actor
      @metadata = metadata || {}
    end

    def call
      metadata.deep_stringify_keys.merge(actor_metadata)
    end

    private
      attr_reader :actor, :metadata

      def actor_metadata
        return {} unless actor

        {
          "actor_type" => actor.class.name,
          "actor_id" => actor.respond_to?(:id) ? actor.id : nil,
          "actor_label" => actor_label
        }.compact
      end

      def actor_label
        return actor.email if actor.respond_to?(:email)
        return actor.name if actor.respond_to?(:name)

        actor.to_s
      end
  end
end
