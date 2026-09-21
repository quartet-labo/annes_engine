module AnnesInquiry
  module Flows
    module Definitions
      class CloneVersion
        def self.call(version)
          Flow.find(version.flow_id).with_lock do
            source = FlowVersion.find(version.id)
            raise Error, "公開済み版を複製してください。" if source.draft?
            raise Error, "すでに下書きがあります。" if source.flow.versions.draft.exists?
            copy = source.dup
            copy.assign_attributes(status: "draft", published_at: nil, number: source.flow.versions.maximum(:number) + 1, lock_version: 0)
            copy.save!
            source.steps.each { |step| copy.steps.create!(step.attributes.except("id", "flow_version_id", "created_at", "updated_at")) }
            copy
          end
        end
      end
    end
  end
end
