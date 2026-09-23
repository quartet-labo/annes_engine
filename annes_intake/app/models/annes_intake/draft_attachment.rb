module AnnesIntake
  class DraftAttachment < ApplicationRecord
    belongs_to :step_run, class_name: "AnnesIntake::StepRun"
    belongs_to :field, class_name: "AnnesIntake::Field"
    has_one_attached :file, dependent: false
  end
end
