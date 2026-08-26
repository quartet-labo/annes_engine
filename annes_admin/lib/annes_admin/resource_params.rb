module AnnesAdmin
  class ResourceParams
    def initialize(resource, params)
      @resource = resource
      @params = params
    end

    def permitted
      params.fetch(resource.param_key, ActionController::Parameters.new).permit(*resource.permitted_attributes)
    end

    private
      attr_reader :resource, :params
  end
end
