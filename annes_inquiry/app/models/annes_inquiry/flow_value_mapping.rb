module AnnesInquiry
  class FlowValueMapping < ApplicationRecord
    include DraftDefinition
    belongs_to :flow_step, class_name: "AnnesInquiry::FlowStep"
    belongs_to :source_step, class_name: "AnnesInquiry::FlowStep"
    belongs_to :source_field, class_name: "AnnesInquiry::Field"
    belongs_to :target_field, class_name: "AnnesInquiry::Field"
    validates :target_field_id, uniqueness: {scope: :flow_step_id}

    private
      def definition_owner_attribute = :flow_step_id
      def definition_version = flow_step.flow_version.reload
  end
end
