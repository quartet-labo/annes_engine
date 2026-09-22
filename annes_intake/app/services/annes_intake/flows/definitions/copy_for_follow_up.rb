module AnnesIntake
  module Flows
    module Definitions
      class CopyForFollowUp
        def self.call(source, request, context:, definition_context: context)
          Lock.call(request.root_run, extra_versions: [source]) do
            request.lock!
            raise Conflict if Flow.where(follow_up_request_id: request.id).exists?
            DefinitionPolicy.new(context: definition_context).authorize!(source, action: :admin_view_definition)
            private_context = DefinitionPolicy::Context.new(definition_context: definition_context, run_context: context, follow_up_id: request.id)
            DefinitionPolicy.new(context: private_context).send(:authorize_private!, request, :admin_define)
            raise Forbidden unless request.custom? && request.source_version_id == source.id && request.definition_version_id == source.id
            flow = Flow.create!(key: "follow_up_#{SecureRandom.hex(12)}", name: request.title, follow_up_request: request)
            copy = flow.versions.create!(number: 1, title: request.title)
            forms, fields, steps = {}, {}, {}
            source.steps.each do |step|
              forms[step.form_version_id] ||= begin
                form = Form.create!(key: "follow_up_#{SecureRandom.hex(12)}", name: step.form_version.title, follow_up_request: request)
                version = form.versions.create!(step.form_version.attributes.except("id", "form_id", "created_at", "updated_at", "published_at", "status", "number", "lock_version").merge("number" => 1))
                step.form_version.fields.includes(:options, :file_types).each do |field|
                  target = version.fields.create!(field.attributes.except("id", "form_version_id", "created_at", "updated_at"))
                  field.options.each { |option| target.options.create!(option.attributes.except("id", "field_id", "created_at", "updated_at")) }
                  field.file_types.each { |type| target.file_types.create!(type.attributes.except("id", "field_id", "created_at", "updated_at")) }
                  fields[field.id] = target
                end
                version
              end
              steps[step.id] = copy.steps.create!(key: step.key, title: step.title, position: step.position, form_version: forms.fetch(step.form_version_id))
            end
            source.steps.each do |step|
              target = steps.fetch(step.id)
              step.condition_groups.each do |group|
                new_group = target.condition_groups.create!
                group.conditions.each do |condition|
                  new_group.conditions.create!(source_step: steps.fetch(condition.source_step_id), field: fields.fetch(condition.field_id), operator: condition.operator, expected_value: condition.expected_value)
                end
              end
              step.value_mappings.each do |mapping|
                target.value_mappings.create!(source_step: steps.fetch(mapping.source_step_id), source_field: fields.fetch(mapping.source_field_id), target_field: fields.fetch(mapping.target_field_id))
              end
            end
            copy
          end
        end
      end
    end
  end
end
