module AnnesInquiry
  module Flows
    module Definitions
      class CloneVersion
        def self.call(version)
          Flow.find(version.flow_id).with_lock do
            source = FlowVersion.find(version.id)
            raise Error, "公開済み版を複製してください。" if source.draft?
            raise Error, "発行済みの追加質問は複製できません。" if source.flow.follow_up_request && !source.flow.follow_up_request.draft?
            raise Error, "すでに下書きがあります。" if source.flow.versions.draft.exists?
            copy = source.dup
            copy.assign_attributes(status: "draft", published_at: nil, number: source.flow.versions.maximum(:number) + 1, lock_version: 0)
            copy.save!
            steps = source.steps.to_h { |step| [step.id, copy.steps.create!(step.attributes.except("id", "flow_version_id", "created_at", "updated_at"))] }
            source.steps.each do |step|
              target = steps.fetch(step.id)
              step.condition_groups.each do |group|
                cloned_group = target.condition_groups.create!
                group.conditions.each do |condition|
                  cloned_group.conditions.create!(source_step: steps.fetch(condition.source_step_id), field: condition.field, operator: condition.operator, expected_value: condition.expected_value)
                end
              end
              step.value_mappings.each do |mapping|
                target.value_mappings.create!(source_step: steps.fetch(mapping.source_step_id), source_field: mapping.source_field, target_field: mapping.target_field)
              end
            end
            copy
          end
        end
      end
    end
  end
end
