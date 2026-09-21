module AnnesInquiry
  class FlowConditionGroup < ApplicationRecord
    include DraftDefinition
    belongs_to :flow_step, class_name: "AnnesInquiry::FlowStep"
    has_many :conditions, class_name: "AnnesInquiry::FlowCondition", dependent: :destroy, inverse_of: :flow_condition_group

    private
      def definition_owner_attribute = :flow_step_id
      def definition_version = flow_step.flow_version.reload
  end
end
