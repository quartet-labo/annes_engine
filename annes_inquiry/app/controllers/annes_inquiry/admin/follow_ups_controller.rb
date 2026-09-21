module AnnesInquiry
  module Admin
    class FollowUpsController < ActionController::Base
      protect_from_forgery with: :exception
      include AdminAccess
      include FlowErrors
      helper FlowHelper
      before_action :load_root

      def new
        @request_key = SecureRandom.uuid
        @templates = FlowVersion.published.joins(:flow).where(annes_inquiry_flows: {follow_up_request_id: nil, enabled: true})
      end

      def create
        version = FlowVersion.find(params[:version_id])
        due_at = Time.find_zone!("UTC").parse(params[:due_at].to_s)
        request = Flows::PrepareFollowUp.call(root: @root, version: version, context: @context, request_key: params[:request_key], title: params[:title], due_at: due_at, custom: params[:custom] == "1")
        redirect_to admin_flow_run_follow_up_path(@root.flow, @root, request), status: :see_other
      rescue ArgumentError
        raise Flows::Conflict, "期限が正しくありません。"
      end

      def show
        @follow_up = @root.follow_up_requests.find(params[:id])
        @definition_digest = Flows::FollowUpDefinitionDigest.call(@follow_up)
      end

      def issue
        request = @root.follow_up_requests.find(params[:id])
        Flows::IssueFollowUp.call(request: request, context: @context, expected_lock_version: params[:lock_version], expected_definition_digest: params[:definition_digest])
        redirect_to admin_flow_run_path(@root.flow, @root), status: :see_other
      end

      def cancel
        request = @root.follow_up_requests.find(params[:id])
        Flows::CancelFollowUp.call(request: request, context: @context)
        redirect_to admin_flow_run_path(@root.flow, @root), status: :see_other
      end

      private
        def load_root
          flow = Flow.templates.find(params[:flow_id])
          adapter = AnnesInquiry.configuration.flow_adapters[flow.key]
          raise Flows::Forbidden unless adapter&.respond_to?(:prepare_context)
          @context = adapter.prepare_context(self)
          return if performed?
          policy = Flows::AccessPolicy.new(flow: flow, context: @context)
          @root = policy.scope(FlowRun.joins(:flow_version).where(annes_inquiry_flow_versions: {flow_id: flow.id})).find(params[:run_id])
          policy.authorize!(:admin_view, run: @root)
          policy.authorize!(:admin_follow_up, run: @root)
          raise Flows::Conflict unless @root.submitted? && !@root.follow_up_request
        end
    end
  end
end
