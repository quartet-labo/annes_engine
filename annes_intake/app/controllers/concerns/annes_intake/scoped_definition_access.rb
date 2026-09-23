module AnnesIntake
  module ScopedDefinitionAccess
    extend ActiveSupport::Concern
    included { before_action :load_private_definition_context }
    private
      def load_private_definition_context
        record = case controller_name
        when "flows" then Flow.find(params[:id]) if params[:id]
        when "forms" then Form.find(params[:id]) if params[:id]
        when "versions" then FormVersion.find(params[:id]) if params[:id]
        when "fields" then params[:version_id] ? FormVersion.find(params[:version_id]) : Field.find(params[:id])
        end
        request = DefinitionPolicy.owner(record)&.follow_up_request
        return unless request
        adapter = AnnesIntake.configuration.adapters[request.root_run.flow.key]
        raise Flows::Forbidden unless adapter&.respond_to?(:prepare_context)
        run_context = adapter.prepare_context(self)
        return if performed?
        @definition_context = DefinitionPolicy::Context.new(definition_context: @definition_context, run_context: run_context, follow_up_id: request.id)
        @definition_policy = DefinitionPolicy.new(context: @definition_context)
        definition_record(record)
      end
  end
end
