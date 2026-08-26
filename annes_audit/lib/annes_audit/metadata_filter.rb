module AnnesAudit
  class MetadataFilter
    def initialize(filter_keys: AnnesAudit.configuration.metadata_filter_keys)
      @filter_keys = filter_keys.map(&:to_s)
    end

    def call(metadata)
      normalize(metadata)
    end

    private
      attr_reader :filter_keys

      def normalize(value)
        case value
        when Hash
          value.each_with_object({}) do |(key, nested_value), filtered|
            next if sensitive_key?(key)

            filtered[key.to_s] = normalize(nested_value)
          end
        when Array
          value.map { |item| normalize(item) }
        when Symbol
          value.to_s
        else
          value
        end
      end

      def sensitive_key?(key)
        key_text = key.to_s
        filter_keys.any? { |filter_key| key_text.match?(/#{Regexp.escape(filter_key)}/i) }
      end
  end
end
