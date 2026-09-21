module AnnesInquiry
  class FlowCondition < ApplicationRecord
    include DraftDefinition
    belongs_to :flow_condition_group, class_name: "AnnesInquiry::FlowConditionGroup", inverse_of: :conditions
    belongs_to :source_step, class_name: "AnnesInquiry::FlowStep"
    belongs_to :field, class_name: "AnnesInquiry::Field"
    validates :operator, inclusion: {in: %w[eq contains]}
    validates :expected_value, presence: true

    private
      def definition_owner_attribute = :flow_condition_group_id
      def definition_version = flow_condition_group.flow_step.flow_version.reload
  end
end
