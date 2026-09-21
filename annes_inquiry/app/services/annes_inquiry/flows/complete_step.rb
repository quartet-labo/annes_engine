module AnnesInquiry
  module Flows
    class CompleteStep
      def self.call(run:, step:, context:, token:)
        Lock.call(run) do |current|
          item = current.step_runs.find(step.id)
          policy = AccessPolicy.new(flow: current.flow, context: context)
          policy.authorize!(:complete, run: current, step: item)
          Lock.writable!(current)
          OperationToken.verify!(token, run: current, action: :complete, policy: policy, step: item)
          result = RouteEvaluator.evaluate(current)
          path = result.steps
          index = path.index { |candidate| candidate.id == item.id }
          raise Conflict unless index && path.take(index).all?(&:complete?)
          DraftReader.with_input(item, raw_values: result.raw_values.fetch(item.flow_step_id)) do |input, blobs|
            raise InvalidInput.new(input) unless input.valid?
            if policy.adapter.respond_to?(:validate_step)
              messages = policy.adapter.validate_step(item, input.values, context)
              (messages || {}).each { |key, text| Array(text).each { |message| input.errors.add(key, message) } }
              raise InvalidInput.new(input) if input.errors.any?
            end
          end
          item.update!(status: "complete")
          RouteEvaluator.reconcile!(current)
          current.update!(revision: current.revision + 1)
          item
        end
      end
    end
  end
end
