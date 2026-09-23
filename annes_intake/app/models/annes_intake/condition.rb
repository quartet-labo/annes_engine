module AnnesIntake
  class Condition < ApplicationRecord
    include DraftDefinition
    belongs_to :condition_group, class_name: "AnnesIntake::ConditionGroup", inverse_of: :conditions
    belongs_to :source_step, class_name: "AnnesIntake::Step"
    belongs_to :field, class_name: "AnnesIntake::Field"
    validates :operator, inclusion: {in: %w[eq contains]}
    validates :expected_value, presence: true

    private
      def definition_owner_attribute = :condition_group_id
      def definition_version = condition_group.step.flow_version.reload
  end
end
