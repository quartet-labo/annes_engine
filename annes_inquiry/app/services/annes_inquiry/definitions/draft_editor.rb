module AnnesInquiry
  module Definitions
    class DraftEditor
      def self.call(version, expected_lock_version:)
        Form.find(version.form_id).with_lock do
          draft = FormVersion.find(version.id)
          raise Error, "下書きだけを編集できます。" unless draft.draft?
          expected = Integer(expected_lock_version, exception: false)
          raise ActiveRecord::StaleObjectError.new(draft, "update") unless draft.lock_version == expected

          yield draft
          draft.touch unless draft.destroyed?
          draft
        end
      end
    end
  end
end
