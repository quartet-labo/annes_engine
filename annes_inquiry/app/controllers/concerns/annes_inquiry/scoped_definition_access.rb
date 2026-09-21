module AnnesInquiry
  module ScopedDefinitionAccess
    extend ActiveSupport::Concern
    included do
      include FlowErrors
      before_action :authorize_scoped_definition
    end

    private
      def authorize_scoped_definition
        owner = case controller_name
        when "flows" then Flow.find(params[:id]) if params[:id]
        when "forms" then Form.find(params[:id]) if params[:id]
        when "versions" then FormVersion.find(params[:id]).form if params[:id]
        when "fields"
          params[:version_id] ? FormVersion.find(params[:version_id]).form : Field.find(params[:id]).form_version.form
        end
        return unless owner&.follow_up_request
        root = owner.follow_up_request.root_run
        adapter = AnnesInquiry.configuration.flow_adapters[root.flow.key]
        raise Flows::Forbidden unless adapter&.respond_to?(:prepare_context)
        context = adapter.prepare_context(self)
        return if performed?
        policy = Flows::AccessPolicy.for_run(root, context)
        raise Flows::Forbidden unless policy.scope(FlowRun.where(id: root.id)).exists?
        policy.authorize!(:admin_view, run: root)
        policy.authorize!(:admin_follow_up, run: root) unless request.get?
        if !request.get? && !owner.follow_up_request.draft?
          raise Flows::Conflict, "発行済みの追加質問は変更できません。"
        end
      end
  end
end
