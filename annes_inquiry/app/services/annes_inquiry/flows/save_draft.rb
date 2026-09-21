module AnnesInquiry
  module Flows
    class SaveDraft
      Result = Data.define(:step, :revision)
      MAX_TEXT_BYTES = 100_000
      MAX_VALUES = 1_000
      def self.call(run:, step:, context:, token:, raw_values:, retained_attachments: {})
        Lock.call(run) do |current|
          owned_step = current.step_runs.find(step.id)
          policy = AccessPolicy.new(flow: current.flow, context: context)
          policy.authorize!(:save, run: current, step: owned_step)
          Lock.writable!(current)
          OperationToken.verify!(token, run: current, action: :save, policy: policy, step: owned_step)
          path = RouteEvaluator.call(current)
          index = path.index { |item| item.id == owned_step.id }
          raise Conflict, "前のステップを完了してください。" unless index && path.take(index).all?(&:complete?)
          fields = owned_step.form_version.fields.to_a
          validate_shape!(fields, raw_values, retained_attachments)
          mapped = owned_step.flow_step.value_mappings.includes(:target_field).map { |mapping| mapping.target_field.key }
          raise Conflict, "引継ぎ項目は編集できません。" if (raw_values.keys & mapped).any?
          fields.each do |field|
            next if mapped.include?(field.key)
            if field.value_type == "attachment"
              SaveAttachments.call(owned_step, field, Array(raw_values[field.key]).reject { |v| v == "" }, retained_attachments[field.key])
              next
            end
            answer = owned_step.draft_answers.find_or_initialize_by(field: field)
            answer.form_version_id = owned_step.form_version_id
            value = raw_values[field.key]
            answer.raw_value = value.is_a?(Array) ? nil : value
            answer.save!
            answer.values.destroy_all
            Array(value).each_with_index { |item, position| answer.values.create!(raw_value: item, position: position) } if value.is_a?(Array)
          end
          current.step_runs.joins(:flow_step).where("annes_inquiry_flow_steps.position >= ?", owned_step.flow_step.position).each { |item| item.update!(status: "draft") }
          RouteEvaluator.reconcile!(current)
          current.update!(revision: current.revision + 1)
          Result.new(step: owned_step.reload, revision: current.revision)
        end
      end

      def self.validate_shape!(fields, values, retained)
        raise Conflict, "入力形式が正しくありません。" unless values.is_a?(Hash) && retained.is_a?(Hash) && (values.keys - fields.map(&:key)).empty? && (retained.keys - fields.select { |f| f.value_type == "attachment" }.map(&:key)).empty?
        fields.each do |field|
          value = values[field.key]
          valid = if %w[multiple_choice attachment].include?(field.value_type)
            value.nil? || (value.is_a?(Array) && value.size <= MAX_VALUES && value.all? { |item| safe_string?(item) || (field.value_type == "attachment" && item.is_a?(ActionDispatch::Http::UploadedFile)) })
          else
            value.nil? || safe_string?(value)
          end
          raise Conflict, "入力形式または容量が正しくありません。" unless valid
        end
      end
      def self.safe_string?(value) = value.is_a?(String) && value.valid_encoding? && !value.include?("\0") && value.bytesize <= MAX_TEXT_BYTES
      private_class_method :validate_shape!, :safe_string?
    end
  end
end
