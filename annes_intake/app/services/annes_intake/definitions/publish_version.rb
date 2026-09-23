module AnnesIntake
  module Definitions
    class PublishVersion
      def self.call(version, expected_lock_version:, context: nil)
        DefinitionPolicy.new(context: context).authorize!(version)
        DraftEditor.call(version, expected_lock_version: expected_lock_version, context: context) do |draft|
          Validator.new(draft).validate!
          draft.form.versions.published.update_all(status: "retired", updated_at: Time.current)
          draft.update_columns(status: "published", published_at: Time.current, updated_at: Time.current)
        end
      end
    end
  end
end
