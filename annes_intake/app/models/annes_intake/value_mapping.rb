module AnnesIntake
  class ValueMapping < ApplicationRecord
    include DraftDefinition
    belongs_to :step, class_name: "AnnesIntake::Step"
    belongs_to :source_step, class_name: "AnnesIntake::Step"
    belongs_to :source_field, class_name: "AnnesIntake::Field"
    belongs_to :target_field, class_name: "AnnesIntake::Field"
    validates :target_field_id, uniqueness: {scope: :step_id}

    private
      def definition_owner_attribute = :step_id
      def definition_version = step.flow_version.reload
  end
end
