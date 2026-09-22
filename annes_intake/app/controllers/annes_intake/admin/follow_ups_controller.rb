module AnnesIntake
  module Admin
    class FollowUpsController < ActionController::Base
      protect_from_forgery with: :exception
      include AdminAccess
      include FlowErrors
      include DefinitionErrors
      helper FlowHelper
      before_action :load_root

      def new
        load_template_context
        return if performed?
        @request_key = SecureRandom.uuid
        @templates = @definition_policy.scope(FlowVersion.published).joins(:flow).where(annes_intake_flows: {follow_up_request_id: nil, enabled: true})
      end

      def create
        load_template_context
        return if performed?
        version = @definition_policy.scope(FlowVersion.all).find(params[:version_id])
        due_at = Time.find_zone!("UTC").parse(params[:due_at].to_s)
        request = Flows::PrepareFollowUp.call(root: @root, version: version, context: @context, request_key: params[:request_key], title: params[:title], due_at: due_at, custom: params[:custom] == "1", definition_context: @definition_context)
        redirect_to admin_run_follow_up_path(@root, request), status: :see_other
      rescue ArgumentError
        raise Flows::Conflict, "期限が正しくありません。"
      end

      def show
        @follow_up = @root.follow_up_requests.find(params[:id])
        @definition_digest = Flows::FollowUpDefinitionDigest.call(@follow_up)
      end

      def issue
        request = @root.follow_up_requests.find(params[:id])
        Flows::IssueFollowUp.call(request: request, context: @context, expected_lock_version: params[:lock_version], expected_definition_digest: params[:definition_digest], definition_context: @definition_context)
        redirect_to admin_run_path(@root), status: :see_other
      end

      def cancel
        request = @root.follow_up_requests.find(params[:id])
        Flows::CancelFollowUp.call(request: request, context: @context)
        redirect_to admin_run_path(@root), status: :see_other
      end

      private
        def load_template_context
          authorizer = AnnesIntake.configuration.definition_authorizer
          raise Flows::Forbidden unless authorizer&.respond_to?(:prepare_context)
          @definition_context = authorizer.prepare_context(self, admin: @intake_admin_user)
          return if performed?
          @definition_policy = DefinitionPolicy.new(context: @definition_context)
          @definition_policy.authorize!(nil, action: :admin_view_definition)
        end
        def load_root
          candidate = Run.find(params[:run_id])
          flow = candidate.flow
          raise Flows::Conflict if candidate.follow_up_request
          adapter = AnnesIntake.configuration.adapters[flow.key]
          raise Flows::Forbidden unless adapter&.respond_to?(:prepare_context)
          @context = adapter.prepare_context(self)
          return if performed?
          policy = Flows::AccessPolicy.new(flow: flow, context: @context)
          @root = policy.scope(Run.joins(:flow_version).where(annes_intake_flow_versions: {flow_id: flow.id})).find(params[:run_id])
          policy.authorize!(:admin_view, run: @root)
          @follow_up_policy = policy
          policy.authorize!(:admin_follow_up, run: @root) if %w[new create issue].include?(action_name)
          policy.authorize!(:admin_cancel_follow_up, run: @root) if action_name == "cancel"
          raise Flows::Conflict unless @root.submitted? && !@root.follow_up_request
        end
    end
  end
end
