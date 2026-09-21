module AnnesInquiry
  module Flows
    module Definitions
      class Validator
        def self.call(version)
          raise Error, "ステップを追加してください。" if version.steps.empty?
          version.steps.includes(form_version: :form).each do |step|
            raise Error, "有効な公開フォーム版を選択してください。" unless step.form_version.published? && step.form_version.form.enabled?
            rules!(step)
          end
        end

        def self.rules!(step)
          step.condition_groups.includes(conditions: [:source_step, {field: :options}]).each do |group|
            raise Error, "条件グループには条件が必要です。" if group.conditions.empty?
            group.conditions.each do |condition|
              source!(step, condition.source_step, condition.field)
              field = condition.field
              valid = case field.value_type
              when "boolean" then condition.operator == "eq" && %w[true false].include?(condition.expected_value)
              when "single_choice" then condition.operator == "eq" && field.options.map(&:value).include?(condition.expected_value)
              when "multiple_choice" then condition.operator == "contains" && field.options.map(&:value).include?(condition.expected_value)
              else false
              end
              raise Error, "条件の型・演算子・選択肢が正しくありません。" unless valid
            end
          end
          step.value_mappings.includes(:source_step, :source_field, :target_field).each do |mapping|
            source!(step, mapping.source_step, mapping.source_field)
            from, to = mapping.source_field, mapping.target_field
            raise Error, "引継ぎ先の所属または型が正しくありません。" unless to.form_version_id == step.form_version_id && from.value_type == to.value_type && from.value_type != "attachment"
            if from.choice? && (from.options.map(&:value) - to.options.map(&:value)).any?
              raise Error, "引継ぎ先に元の選択肢が必要です。"
            end
          end
        end

        def self.source!(target, source, field)
          unless source.flow_version_id == target.flow_version_id && source.position < target.position && field.form_version_id == source.form_version_id
            raise Error, "同じフローの前のステップと、その項目を参照してください。"
          end
        end
      end
    end
  end
end
