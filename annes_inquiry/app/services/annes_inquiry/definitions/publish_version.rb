module AnnesInquiry
  module Definitions
    class PublishVersion
      def self.call(version, expected_lock_version:)
        DraftEditor.call(version, expected_lock_version:) do |draft|
          Validator.new(draft).validate!
          adapter = AnnesInquiry.configuration.adapters[draft.form.key]
          adapter.validate_definition!(draft) if adapter&.respond_to?(:validate_definition!)
          draft.form.versions.published.update_all(status: "retired", updated_at: Time.current)
          draft.update_columns(status: "published", published_at: Time.current, updated_at: Time.current)
        end
      end
    end
  end
end
