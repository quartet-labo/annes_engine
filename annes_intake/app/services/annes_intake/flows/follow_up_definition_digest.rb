module AnnesIntake
  module Flows
    class FollowUpDefinitionDigest
      def self.call(request)
        version = request.definition_version.reload
        data = [version.attributes, version.steps.map do |step|
          [step.attributes, step.form_version.attributes,
           step.form_version.fields.map { |field| [field.attributes, field.options.map(&:attributes), field.file_types.order(:id).map(&:attributes)] },
           step.condition_groups.order(:id).map { |group| [group.attributes, group.conditions.order(:id).map(&:attributes)] }, step.value_mappings.order(:id).map(&:attributes)]
        end]
        Digest::SHA256.hexdigest(data.to_json)
      end
    end
  end
end
