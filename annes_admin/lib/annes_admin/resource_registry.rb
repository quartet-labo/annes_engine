module AnnesAdmin
  class ResourceRegistry
    include Enumerable

    def initialize
      @resources = {}
      @sources = {}
    end

    def register(name, model:, source: :manual, **options, &block)
      key = normalize_name(name)
      raise ConfigurationError, "Admin resource #{key.inspect} is already registered" if resources.key?(key)

      ResourceConfig.new(key, model:, **options).tap do |resource|
        resource.instance_eval(&block) if block
        resources[key] = resource
        sources[key] = source.to_sym
      end
    end

    def fetch(name)
      key = normalize_name(name)
      resources.fetch(key) do
        raise ActiveRecord::RecordNotFound, "Admin resource #{key.inspect} is not registered"
      end
    end

    def key?(name)
      resources.key?(normalize_name(name))
    end

    def each(&block)
      resources.values.each(&block)
    end

    def clear
      resources.clear
      sources.clear
    end

    def remove_source(source)
      source = source.to_sym
      sources.select { |_key, registered_source| registered_source == source }.each_key do |key|
        resources.delete(key)
        sources.delete(key)
      end
    end

    private
      attr_reader :resources, :sources

      def normalize_name(name)
        name.to_s
      end
  end
end
