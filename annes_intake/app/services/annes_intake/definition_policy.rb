module AnnesIntake
  class DefinitionPolicy
    Context = Data.define(:definition_context, :run_context, :follow_up_id)

    def self.owner(record)
      case record
      when Form, Flow then record
      when FormVersion then record.form
      when FlowVersion then record.flow
      when Field then record.form_version.form
      end
    end

    # All private editor writes share the issue/finalize lock order.
    def self.lock(record, context:)
      request = owner(record)&.follow_up_request
      return yield unless request
      Flows::Lock.call(request.root_run, extra_versions: [request.definition_version]) do
        request.lock!
        new(context: context).authorize!(record)
        yield
      end
    end

    def initialize(context:)
      @context = context
      @authorizer = AnnesIntake.configuration.definition_authorizer
      raise Flows::Forbidden unless @authorizer && %i[scope_definitions authorize!].all? { |method| @authorizer.respond_to?(method) }
    end

    def scope(relation)
      request_id = @context.is_a?(Context) ? @context.follow_up_id : nil
      owned = case relation.klass.name
      when "AnnesIntake::Flow" then relation.where(follow_up_request_id: request_id)
      when "AnnesIntake::Form" then relation.where(follow_up_request_id: request_id)
      when "AnnesIntake::FlowVersion" then relation.where(flow_id: Flow.where(follow_up_request_id: request_id).select(:id))
      when "AnnesIntake::FormVersion" then relation.where(form_id: Form.where(follow_up_request_id: request_id).select(:id))
      when "AnnesIntake::Field" then relation.where(form_version_id: FormVersion.where(form_id: Form.where(follow_up_request_id: request_id).select(:id)).select(:id))
      else raise Flows::Forbidden
      end
      if request_id
        authorize_private!(FollowUpRequest.find(request_id), :admin_view_definition)
        return owned
      end
      scoped = @authorizer.scope_definitions(owned, context: @context)
      raise Flows::Forbidden unless scoped.is_a?(ActiveRecord::Relation) && scoped.klass == relation.klass
      owned.where(id: scoped.select(:id))
    end

    def authorize!(record, action: :admin_define)
      if request = self.class.owner(record)&.follow_up_request
        return authorize_private!(request, action)
      end
      raise ActiveRecord::RecordNotFound if @context.is_a?(Context) && record
      if record&.persisted?
        raise ActiveRecord::RecordNotFound unless scope(record.class.all).exists?(record.id)
      end
      host_context = @context.is_a?(Context) ? @context.definition_context : @context
      raise Flows::Forbidden unless @authorizer.authorize!(action: action, record: record, context: host_context) == true
      true
    end

    private
      def authorize_private!(request, action)
        raise ActiveRecord::RecordNotFound unless @context.is_a?(Context) && @context.follow_up_id == request.id
        root = request.root_run
        policy = Flows::AccessPolicy.for_run(root, @context.run_context)
        raise ActiveRecord::RecordNotFound unless policy.scope(Run.where(id: root.id)).exists?
        policy.authorize!(:admin_view, run: root)
        unless action == :admin_view_definition
          policy.authorize!(:admin_follow_up, run: root)
          raise Flows::Conflict, "発行済みの追加質問は変更できません。" unless request.reload.draft?
        end
        true
      end
  end
end
