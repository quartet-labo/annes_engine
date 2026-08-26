module AnnesAdmin
  class Query
    attr_reader :resource, :params, :pagination, :base_relation

    def initialize(resource, params, relation: nil)
      @resource = resource
      @params = params
      @base_relation = relation
      @pagination = Pagination.new(params[:page], params[:per_page])
    end

    def relation
      @relation ||= begin
        scoped = apply_scope(base_relation || resource.relation)
        searched = Search.new(resource, scoped, params[:q]).apply
        Sort.new(resource, searched, params[:sort], params[:direction]).apply
      end
    end

    def records
      pagination.apply(relation)
    end

    def total_count
      relation.count
    end

    private
      def apply_scope(relation)
        scope = resource.scopes[params[:scope].to_s]
        return relation unless scope

        block = scope[:block]
        return block.call(relation) if block
        return relation.public_send(scope[:name]) if relation.respond_to?(scope[:name])

        relation
      end
  end
end
