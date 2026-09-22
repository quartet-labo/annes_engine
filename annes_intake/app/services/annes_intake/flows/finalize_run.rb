module AnnesIntake
  module Flows
    class FinalizeRun
      def self.call(run:, context:, token:)
        Lock.call(run) do |current|
          policy = AccessPolicy.new(flow: current.flow, context: context)
          policy.authorize!(:finalize, run: current)
          data = OperationToken.verify!(token, run: current, action: :finalize, policy: policy, replay: current.submitted?)
          if current.submitted?
            raise Conflict unless data["request_key"] == current.final_key
            next current
          end
          Lock.writable!(current)
          result = RouteEvaluator.evaluate(current)
          steps = result.steps
          raise Conflict, "すべてのステップを確認してください。" unless steps.present? && steps.all?(&:complete?)
          response = current.create_response!
          payload = {}
          steps.each do |step|
            DraftReader.with_input(step, raw_values: result.raw_values.fetch(step.step_id)) do |input, blobs|
              raise InvalidInput.new(input) unless input.valid?
              if policy.adapter.respond_to?(:validate_step)
                (policy.adapter.validate_step(step, input.values, context) || {}).each { |key, messages| Array(messages).each { |message| input.errors.add(key, message) } }
                raise InvalidInput.new(input) if input.errors.any?
              end
              digest = PayloadDigest.call(input.values, identity: policy.owner_digest, context: {"run" => current.id, "step" => step.id})
              step_response = StepResponse.create!(response: response, run_id: current.id, step_run_id: step.id, step_key: step.key, form_version: step.form_version, payload_digest: digest)
              AnnesIntake::AnswerWriter.call(step_response, input.values, blobs: blobs)
              step.update!(step_response: step_response)
              payload[step.key] = RunPayload.call(input.values)
            end
          end
          if policy.adapter.respond_to?(:validate_run)
            messages = policy.adapter.validate_run(current, payload, context)
            raise Error, Array(messages).join("、") if messages.present?
          end
          raise Forbidden, "フロー保存adapterを設定してください。" unless policy.adapter.respond_to?(:persist!)
          policy.adapter.persist!(current, payload, context)
          digest = Digest::SHA256.hexdigest(steps.map { |step| step.reload.step_response.payload_digest }.join(":"))
          current.update!(status: "submitted", final_key: data.fetch("request_key"), payload_digest: digest, submitted_at: Time.current, submitted_revision: current.revision, revision: current.revision + 1)
          if policy.adapter.respond_to?(:deliver)
            request = current.notification_requests.create!(event_key: "received")
            ActiveRecord.after_all_transactions_commit { NotificationDispatcher.call(request.id) }
          end
          current
        end
      end
    end
  end
end
