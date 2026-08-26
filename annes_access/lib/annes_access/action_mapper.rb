module AnnesAccess
  class ActionMapper
    STANDARD_ACTIONS = %w[read create update destroy manage].freeze

    attr_reader :aliases

    def initialize(aliases = AnnesAccess.configuration.action_aliases)
      @aliases = aliases.to_h.transform_keys { |key| normalize_key(key) }.transform_values { |value| normalize_key(value) }
    end

    def map(action)
      normalized = normalize_key(action)
      aliases.fetch(normalized, normalized)
    end

    def standard?(action)
      STANDARD_ACTIONS.include?(map(action))
    end

    private
      def normalize_key(value)
        value.to_s.strip.downcase
      end
  end
end
