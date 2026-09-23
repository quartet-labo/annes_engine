module AnnesIntake
  module Flows
    class RouteEvaluator
      Result = Data.define(:steps, :raw_values, :inputs)

      def self.call(run)
        return run.step_runs.where.not(step_response_id: nil).joins(:step).order("annes_intake_steps.position").to_a if run.submitted?
        evaluate(run).steps
      end

      def self.raw_values(step) = evaluate(step.run).raw_values.fetch(step.step_id, {})

      def self.evaluate(run)
        steps = run.step_runs.includes(:step).sort_by { |step| step.step.position }
        evaluate_steps(steps, definition: ->(step) { step.step }, raw: ->(step) { DraftReader.call(step) }, complete: ->(step) { step.complete? })
      end

      # Preview uses precisely the same ordered rule and mapping evaluation.
      def self.preview(version, answers)
        evaluate_steps(version.steps.to_a, definition: ->(step) { step }, raw: ->(step) { answers.fetch(step.key, {}) }, complete: ->(step) { true }, require_valid: true)
      end

      def self.evaluate_steps(steps, definition:, raw:, complete:, require_valid: false)
        active, values, raws, inputs = [], {}, {}, {}
        steps.each do |step|
          rule = definition.call(step)
          next unless active?(rule, values)
          active << step
          effective = ValueMapper.call(rule, raw.call(step), values)
          raws[rule.id] = effective
          input = Input.new(rule.form_version, raw_values: effective)
          inputs[rule.id] = input
          valid = input.valid?
          # Attachments are revalidated by completion/finalization. Only valid scalar
          # fields from a completed active step can drive rules or mapped values.
          if complete.call(step) && (!require_valid || valid)
            values[rule.id] = input.values.reject { |key, value| input.errors[key].any? || rule.form_version.fields.find { |field| field.key == key }.value_type == "attachment" }
          end
        end
        Result.new(steps: active, raw_values: raws, inputs: inputs)
      end

      def self.active?(step, values)
        groups = step.condition_groups.includes(conditions: :field).to_a
        groups.empty? || groups.any? do |group|
          group.conditions.any? && group.conditions.all? do |condition|
            value = values.dig(condition.source_step_id, condition.field.key)
            expected = condition.field.value_type == "boolean" ? condition.expected_value == "true" : condition.expected_value
            !value.nil? && (condition.operator == "contains" ? Array(value).include?(expected) : value == expected)
          end
        end
      end

      def self.reconcile!(run)
        ids = call(run).map(&:id)
        run.step_runs.each do |step|
          state = ids.include?(step.id) ? (step.inactive? ? "draft" : step.status) : "inactive"
          step.update!(status: state) if state != step.status
        end
        run.step_runs.reset
      end
    end
  end
end
