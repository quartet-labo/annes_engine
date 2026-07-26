module AnneLoyalty
  class SourceReference
    attr_reader :type, :key

    def self.resolve(source)
      new(source).tap(&:validate!)
    end

    def initialize(source)
      @source = source
      @type = resolve_type
      @key = resolve_key
    end

    def validate!
      return self if type.present? && key.present?

      raise InvalidSourceError, "source must provide both type and key"
    end

    private
      attr_reader :source

      def resolve_type
        if source.respond_to?(:key?)
          source[:type] || source["type"] || source[:source_type] || source["source_type"]
        elsif source.respond_to?(:class)
          source.class.name
        end.to_s.strip.presence
      end

      def resolve_key
        raw_key =
          if source.respond_to?(:key?)
            source[:key] || source["key"] || source[:source_key] || source["source_key"]
          elsif source.respond_to?(:loyalty_source_key)
            source.loyalty_source_key
          elsif source.respond_to?(:to_gid_param)
            source.to_gid_param
          elsif source.respond_to?(:id)
            source.id
          end

        raw_key.to_s.strip.presence
      end
  end
end
