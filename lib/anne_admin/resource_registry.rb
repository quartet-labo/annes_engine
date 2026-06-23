module AnneAdmin
  class ResourceRegistry
    include Enumerable

    def initialize
      @resources = {}
    end

    def register(name, model:, **options, &block)
      key = normalize_name(name)
      raise ConfigurationError, "Admin resource #{key.inspect} is already registered" if resources.key?(key)

      ResourceConfig.new(key, model:, **options).tap do |resource|
        resource.instance_eval(&block) if block
        resources[key] = resource
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
    end

    private
      attr_reader :resources

      def normalize_name(name)
        name.to_s
      end
  end
end
