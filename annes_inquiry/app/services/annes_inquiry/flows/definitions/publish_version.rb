module AnnesInquiry
  module Flows
    module Definitions
      class PublishVersion
        def self.call(version, expected_lock_version:)
          DraftEditor.call(version, expected_lock_version:) do |draft|
            ids = FormVersion.where(id: draft.steps.select(:form_version_id)).pluck(:form_id)
            Form.where(id: ids).order(:id).lock.load
            Validator.call(draft)
            draft.flow.versions.published.update_all(status: "retired", updated_at: Time.current)
            draft.update_columns(status: "published", published_at: Time.current)
          end
        end
      end
    end
  end
end
