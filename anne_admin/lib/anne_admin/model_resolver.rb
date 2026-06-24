module AnneAdmin
  class ModelResolver
    def initialize(model_name)
      @model_name = model_name.to_s
    end

    def call
      model_name.constantize
    rescue NameError => error
      raise ConfigurationError, "Admin resource model #{model_name.inspect} could not be resolved: #{error.message}"
    end

    private
      attr_reader :model_name
  end
end
