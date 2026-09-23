module AnnesIntake
  class ConditionGroup < ApplicationRecord
    include DraftDefinition
    belongs_to :step, class_name: "AnnesIntake::Step"
    has_many :conditions, class_name: "AnnesIntake::Condition", dependent: :destroy, inverse_of: :condition_group

    private
      def definition_owner_attribute = :step_id
      def definition_version = step.flow_version.reload
  end
end
