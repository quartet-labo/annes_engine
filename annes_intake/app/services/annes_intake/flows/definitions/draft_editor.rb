module AnnesIntake
  module Flows
    module Definitions
      class DraftEditor
        def self.call(version, expected_lock_version:, context: nil)
          DefinitionPolicy.new(context: context).authorize!(version)
          Flow.find(version.flow_id).with_lock do
            draft = FlowVersion.find(version.id)
            raise Error, "下書きだけを編集できます。" unless draft.draft?
            raise ActiveRecord::StaleObjectError.new(draft, "update") unless draft.lock_version == Integer(expected_lock_version, exception: false)
            yield draft
            draft.touch unless draft.destroyed?
            draft
          end
        end
      end
    end
  end
end
