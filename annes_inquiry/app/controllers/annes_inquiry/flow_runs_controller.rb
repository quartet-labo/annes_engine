module AnnesInquiry
  class FlowRunsController < ActionController::Base
    protect_from_forgery with: :exception
    include FlowErrors
    helper FormHelper, FlowHelper
    layout "annes_inquiry/flow"
    before_action :require_endpoint
    before_action :load_context

    def new
      @start_key = SecureRandom.uuid
    end

    def create
      run = Flows::StartRun.call(flow: @flow, context: @context, request_key: params[:request_key])
      redirect_to flow_run_path(run), status: :see_other
    end

    def show
      @policy.authorize!(:view, run: @run)
      @steps = Flows::RouteEvaluator.call(@run)
      @follow_ups = Flows::FollowUpReader.call(root: @run, context: @context) if @run.submitted? && !@run.follow_up_request
    end

    def resume
      Flows::ResumeRun.call(run: @run, context: @context)
      redirect_to flow_run_path(@run), notice: "再開しました。", status: :see_other
    end

    def step
      load_step
      @policy.authorize!(:view, run: @run, step: @step)
      Flows::Lock.writable!(@run)
      path = Flows::RouteEvaluator.call(@run)
      index = path.index { |item| item.id == @step.id }
      raise Flows::Conflict unless index && path.take(index).all?(&:complete?)
      @input = Input.new(@step.form_version, raw_values: Flows::RouteEvaluator.raw_values(@step))
      @token = Flows::OperationToken.issue(run: @run, step: @step, action: :save, context: @context)
    end

    def save
      load_step
      raw = params[:inquiry].is_a?(ActionController::Parameters) ? params[:inquiry].to_unsafe_h : (params[:inquiry] || {})
      retained = params[:retained].is_a?(ActionController::Parameters) ? params[:retained].to_unsafe_h : (params[:retained] || {})
      retained.transform_values! { |ids| Array(ids).reject(&:blank?) } if retained.is_a?(Hash)
      saved = Flows::SaveDraft.call(run: @run, step: @step, context: @context, token: params[:token], raw_values: raw, retained_attachments: retained)
      if params[:advance] == "1"
        @run.reload
        raise Flows::Conflict unless @run.revision == saved.revision
        token = Flows::OperationToken.issue(run: @run, step: @step, action: :complete, context: @context)
        Flows::CompleteStep.call(run: @run, step: @step, context: @context, token: token)
      end
      redirect_to flow_run_path(@run), notice: "保存しました。", status: :see_other
    rescue Flows::InvalidInput => error
      @input = Input.new(@step.form_version, raw_values: Flows::RouteEvaluator.raw_values(@step).merge(raw))
      error.input.errors.each { |entry| @input.errors.add(entry.attribute, entry.message) }
      @token = Flows::OperationToken.issue(run: @run.reload, step: @step, action: :save, context: @context)
      render :step, status: :unprocessable_entity
    end

    def review
      @policy.authorize!(:view, run: @run)
      Flows::Lock.writable!(@run)
      result = Flows::RouteEvaluator.evaluate(@run)
      @steps = result.steps
      raise Flows::Conflict, "各ステップの入力を完了してください。" unless @steps.all?(&:complete?)
      @answers = @steps.to_h { |step| [step.key, result.raw_values.fetch(step.flow_step_id)] }
      @token = Flows::OperationToken.issue(run: @run, action: :finalize, context: @context)
    end

    def finalize
      Flows::FinalizeRun.call(run: @run, context: @context, token: params[:token])
      redirect_to flow_run_path(@run), status: :see_other
    end

    def cancel
      Flows::CancelRun.call(run: @run, context: @context, token: params[:token])
      redirect_to flow_run_path(@run), status: :see_other
    end

    def attachment
      load_step
      @policy.authorize!(:attachment, run: @run, step: @step)
      attachment = if params[:kind] == "answer"
        raise ActiveRecord::RecordNotFound unless @step.submission
        AnswerAttachment.where(answer_id: @step.submission.answers.select(:id)).find(params[:attachment_id])
      else
        @step.draft_attachments.find(params[:attachment_id])
      end
      response.headers["Cache-Control"] = "private, no-store"
      send_data attachment.file.download, filename: attachment.file.filename.to_s, type: "application/octet-stream", disposition: "attachment"
    end

    private
      def require_endpoint
        response.headers["Cache-Control"] = "private, no-store"
        head :not_found unless AnnesInquiry.configuration.flow_endpoints_enabled
      end

      def load_context
        if params[:id]
          @run = FlowRun.find(params[:id])
          @flow = @run.flow
        else
          @flow = Flow.find_by!(key: params[:key])
        end
        raise Flows::Forbidden if !@run && @flow.follow_up_request_id
        adapter = AnnesInquiry.configuration.flow_adapters[(@run ? @run.adapter_flow : @flow).key]
        raise Flows::Forbidden unless adapter&.respond_to?(:prepare_context)
        @context = adapter.prepare_context(self)
        return if performed?
        @policy = @run ? Flows::AccessPolicy.for_run(@run, @context) : Flows::AccessPolicy.new(flow: @flow, context: @context)
        @policy.authorize!(@run ? :view : :start, run: @run)
      end

      def load_step
        @step = @run.step_runs.find(params[:step_id])
      end
  end
end
