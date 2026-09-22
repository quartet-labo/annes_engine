module AnnesIntake
  module Admin
    class RunsController < ActionController::Base
      protect_from_forgery with: :exception
      include AdminAccess
      include FlowErrors
      helper FlowHelper
      before_action :load_flow_context, except: :index

      def index
        scope = Run.none
        Flow.templates.where(key: AnnesIntake.configuration.adapters.keys).order(:id).each do |flow|
          adapter = AnnesIntake.configuration.adapters.fetch(flow.key)
          raise Flows::Forbidden unless adapter.respond_to?(:prepare_context)
          context = adapter.prepare_context(self)
          return if performed?
          policy = Flows::AccessPolicy.new(flow: flow, context: context)
          policy.authorize!(:admin_list)
          relation = Run.joins(:flow_version).where(annes_intake_flow_versions: {flow_id: flow.id})
          scope = scope.or(Run.where(id: policy.scope(relation).select(:id)))
        end
        scope = scope.joins(:flow_version).where(annes_intake_flow_versions: {flow_id: params[:flow_id]}) if params[:flow_id].present?
        scope = scope.where.not(id: FollowUpRequest.where.not(response_run_id: nil).select(:response_run_id))
        scope = scope.where(status: params[:status]) if Run.statuses.key?(params[:status])
        %w[from to].each do |key|
          next if params[key].blank?
          date = Date.iso8601(params[key])
          scope = key == "from" ? scope.where("annes_intake_runs.created_at >= ?", date.beginning_of_day) : scope.where("annes_intake_runs.created_at < ?", date.next_day.beginning_of_day)
        end
        @runs = scope.includes(:flow_version).order(id: :desc).limit(50).offset([params[:page].to_i - 1, 0].max * 50)
      rescue Date::Error
        raise Flows::Conflict, "日付が正しくありません。"
      end

      def show
        load_run
        @steps = @run.step_runs.where.not(status: "inactive").includes(:step, form_version: :fields, draft_answers: [:field, :values], draft_attachments: {file_attachment: :blob}, step_response: {answers: {attachments: {file_attachment: :blob}}})
        @follow_ups = Flows::FollowUpReader.call(root: @run, context: @context, action: :admin_view) if @run.submitted? && !@run.follow_up_request
        @answers = Flows::AnswerReader.call(run: @run, context: @context, action: :admin_view) if @run.submitted?
        @draft_values = Flows::RouteEvaluator.evaluate(@run).raw_values unless @run.submitted?
      end

      def attachment
        load_run
        step = @run.step_runs.find(params[:step_id])
        @policy.authorize!(:admin_attachment, run: @run, step: step)
        record = if params[:kind] == "answer"
          raise ActiveRecord::RecordNotFound unless step.step_response
          AnswerAttachment.where(answer_id: step.step_response.answers.select(:id)).find(params[:attachment_id])
        else
          step.draft_attachments.find(params[:attachment_id])
        end
        response.headers["Cache-Control"] = "private, no-store"
        send_data record.file.download, filename: record.file.filename.to_s, type: "application/octet-stream", disposition: "attachment"
      end

      private
        def load_flow_context
          @context_run = Run.find(params[:id])
          @flow = @context_run.flow
          adapter = AnnesIntake.configuration.adapters[@context_run.adapter_flow.key]
          raise Flows::Forbidden unless adapter&.respond_to?(:prepare_context)
          @context = adapter.prepare_context(self)
          return if performed?
          @policy = Flows::AccessPolicy.for_run(@context_run, @context)
          @policy.authorize!(:admin_list)
        end
        def load_run
          relation = Run.joins(:flow_version).where(annes_intake_flow_versions: {flow_id: @flow.id})
          @run = @policy.scope(relation).find(params[:id])
          @policy.authorize!(:admin_view, run: @run)
        end
    end
  end
end
