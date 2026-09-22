module AnnesIntake
  class DefinitionPolicy
    def initialize(context:)
      @context = context
      @authorizer = AnnesIntake.configuration.definition_authorizer
      raise Flows::Forbidden unless @authorizer && %i[scope_definitions authorize!].all? { |method| @authorizer.respond_to?(method) }
    end
    def scope(relation)
      scoped = @authorizer.scope_definitions(relation, context: @context)
      raise Flows::Forbidden unless scoped.is_a?(ActiveRecord::Relation) && scoped.klass == relation.klass
      relation.where(id: scoped.select(:id))
    end
    def authorize!(record, action: :admin_define)
      if record&.persisted?
        raise ActiveRecord::RecordNotFound unless scope(record.class.all).exists?(record.id)
      end
      raise Flows::Forbidden unless @authorizer.authorize!(action: action, record: record, context: @context) == true
      true
    end
  end
end
