module AnnesIntake
  class RunsController < ActionController::Base
    protect_from_forgery with: :exception
    include FlowErrors
    helper FormHelper, FlowHelper
    layout "annes_intake/flow"
    before_action :require_endpoint
    before_action :load_context

    def new
      @start_key = SecureRandom.uuid
    end

    def create
      run = Flows::StartRun.call(flow: @flow, context: @context, request_key: params[:request_key])
      redirect_to step_path(run, step_id: Flows::RouteEvaluator.call(run).first.id), status: :see_other
    end

    def show
      @policy.authorize!(:view, run: @run)
      @steps = Flows::RouteEvaluator.call(@run)
    end

    def resume
      Flows::ResumeRun.call(run: @run, context: @context)
      redirect_to next_input_path(@run.reload), notice: "入力を再開しました。", status: :see_other
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
      raw = params[:intake].is_a?(ActionController::Parameters) ? params[:intake].to_unsafe_h : (params[:intake] || {})
      retained = params[:retained].is_a?(ActionController::Parameters) ? params[:retained].to_unsafe_h : (params[:retained] || {})
      retained.transform_values! { |ids| Array(ids).reject(&:blank?) } if retained.is_a?(Hash)
      saved = Flows::SaveDraft.call(run: @run, step: @step, context: @context, token: params[:token], raw_values: raw, retained_attachments: retained)
      if params[:advance] == "1"
        @run.reload
        raise Flows::Conflict unless @run.revision == saved.revision
        token = Flows::OperationToken.issue(run: @run, step: @step, action: :complete, context: @context)
        Runs::CompleteStep.call(run: @run, step: @step, context: @context, token: token, expected_revision: saved.revision)
        redirect_to next_input_path(@run.reload), status: :see_other
        return
      end
      redirect_to run_path(@run), notice: "保存しました。", status: :see_other
    rescue Flows::Conflict => error
      @unsaved_input = true
      @input = Input.new(@step.form_version, raw_values: raw || {})
      @input.errors.add(:base, "#{error.message} 未保存の入力はこの画面に残っています。再読み込みすると破棄されます。")
      @token = params[:token]
      render :step, status: :conflict
    rescue Flows::InvalidInput => error
      @unsaved_input = saved.nil?
      @input = Input.new(@step.form_version, raw_values: Flows::RouteEvaluator.raw_values(@step).merge(raw))
      error.input.errors.each { |entry| @input.errors.add(entry.attribute, entry.message) }
      @token = Flows::OperationToken.issue(run: @run.reload, step: @step, action: :save, context: @context)
      render :step, status: :unprocessable_entity
    end

    def review
      result = Runs::Review.call(run: @run, context: @context)
      @run, @steps, @answers, @token = result.run, result.steps, result.answers, result.token
    end

    def finalize
      Runs::Finalize.call(run: @run, context: @context, token: params[:token])
      redirect_to run_path(@run), status: :see_other
    end

    def cancel
      Flows::CancelRun.call(run: @run, context: @context, token: params[:token])
      redirect_to run_path(@run), status: :see_other
    end

    def attachment
      load_step
      @policy.authorize!(:attachment, run: @run, step: @step)
      attachment = if params[:kind] == "answer"
        raise ActiveRecord::RecordNotFound unless @step.step_response
        AnswerAttachment.where(answer_id: @step.step_response.answers.select(:id)).find(params[:attachment_id])
      else
        @step.draft_attachments.find(params[:attachment_id])
      end
      response.headers["Cache-Control"] = "private, no-store"
      send_data attachment.file.download, filename: attachment.file.filename.to_s, type: "application/octet-stream", disposition: "attachment"
    end

    private
      def next_input_path(run)
        item = Flows::RouteEvaluator.call(run).find { |step| !step.complete? }
        item ? step_path(run, step_id: item.id) : review_run_path(run)
      end
      def require_endpoint
        response.headers["Cache-Control"] = "private, no-store"
        head :not_found unless AnnesIntake.configuration.endpoints_enabled
      end

      def load_context
        if params[:id]
          @run = Run.find(params[:id])
          @flow = @run.flow
        else
          @flow = Flow.find_by!(key: params[:key])
        end
        adapter = AnnesIntake.configuration.adapters[@flow.key]
        raise Flows::Forbidden unless adapter&.respond_to?(:prepare_context)
        @context = adapter.prepare_context(self)
        return if performed?
        @policy = Flows::AccessPolicy.new(flow: @flow, context: @context)
        @policy.authorize!(@run ? :view : :start, run: @run)
      end

      def load_step
        @step = @run.step_runs.find(params[:step_id])
      end
  end
end
