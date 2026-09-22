module AnnesIntake
  module Flows
    module Definitions
      class PublishVersion
        def self.call(version, expected_lock_version:, context: nil)
          DefinitionPolicy.new(context: context).authorize!(version)
          DraftEditor.call(version, expected_lock_version: expected_lock_version, context: context) do |draft|
            ids = FormVersion.where(id: draft.steps.select(:form_version_id)).pluck(:form_id)
            Form.where(id: ids).order(:id).lock.load
            draft.steps.includes(:form_version).each { |step| DefinitionPolicy.new(context: context).authorize!(step.form_version, action: :admin_view_definition) }
            Validator.call(draft)
            draft.flow.versions.published.update_all(status: "retired", updated_at: Time.current)
            draft.update_columns(status: "published", published_at: Time.current)
          end
        end
      end
    end
  end
end
