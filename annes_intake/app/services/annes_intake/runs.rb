module AnnesIntake
  module Runs
    Start = Flows::StartRun
    Resume = Flows::ResumeRun
    Cancel = Flows::CancelRun
    class SaveDraft
      Result = Data.define(:run, :step, :revision)
      def self.call(run:, step:, context:, token:, raw_values:, retained_attachment_ids: {})
        result = Flows::SaveDraft.call(run: run, step: step, context: context, token: token, raw_values: raw_values, retained_attachments: retained_attachment_ids)
        Result.new(run: run.reload, step: result.step, revision: result.revision)
      end
    end
    class CompleteStep
      Result = Data.define(:run, :step, :revision, :next_step)
      def self.call(run:, step:, context:, token:, expected_revision:)
        current = Flows::CompleteStep.call(run: run, step: step, context: context, token: token, expected_revision: expected_revision)
        run.reload
        Result.new(run: run, step: current, revision: run.revision, next_step: Flows::RouteEvaluator.call(run).find { |item| !item.complete? })
      end
    end
    class Review
      Result = Data.define(:run, :steps, :answers, :token)
      def self.call(run:, context:)
        Flows::Lock.call(run) do |current|
          policy = Flows::AccessPolicy.new(flow: current.flow, context: context)
          policy.authorize!(:view, run: current)
          Flows::Lock.writable!(current)
          route = Flows::RouteEvaluator.evaluate(current)
          raise Flows::Conflict, "各ステップの入力を完了してください。" unless route.steps.any? && route.steps.all?(&:complete?)
          answers = route.steps.to_h do |step|
            values = nil
            Flows::DraftReader.with_input(step, raw_values: route.raw_values.fetch(step.step_id)) do |input, blobs|
              raise Flows::InvalidInput.new(input) unless input.valid?
              if policy.adapter.respond_to?(:validate_step)
                (policy.adapter.validate_step(step, input.values, context) || {}).each { |key, messages| Array(messages).each { |message| input.errors.add(key, message) } }
                raise Flows::InvalidInput.new(input) if input.errors.any?
              end
              values = RunPayload.call(input.values)
            end
            [step.key, values]
          end
          if policy.adapter.respond_to?(:validate_run)
            errors = policy.adapter.validate_run(current, answers, context)
            raise Flows::Error, Array(errors).join("、") if errors.present?
          end
          Result.new(run: current, steps: route.steps, answers: answers, token: Flows::OperationToken.issue(run: current, action: :finalize, context: context))
        end
      end
    end
    class Finalize
      Result = Data.define(:run, :response, :replayed)
      def self.call(run:, context:, token:)
        Flows::Lock.call(run) do |current|
          replayed = current.submitted?
          saved = Flows::FinalizeRun.call(run: current, context: context, token: token)
          Result.new(run: saved, response: saved.response, replayed: replayed)
        end
      end
    end
  end
end
