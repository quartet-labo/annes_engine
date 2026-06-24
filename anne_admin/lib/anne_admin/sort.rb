module AnneAdmin
  class Sort
    DIRECTIONS = %w[asc desc].freeze

    def initialize(resource, relation, sort_param, direction_param)
      @resource = resource
      @relation = relation
      @sort_param = sort_param.to_s
      @direction_param = direction_param.to_s.downcase
    end

    def apply
      return relation if sort_param.blank?
      return relation unless resource.sortable_attributes.include?(sort_param.to_sym)
      return relation unless resource.model_class.column_names.include?(sort_param)

      relation.reorder(sort_param => direction)
    end

    def direction
      DIRECTIONS.include?(direction_param) ? direction_param : "asc"
    end

    private
      attr_reader :resource, :relation, :sort_param, :direction_param
  end
end
