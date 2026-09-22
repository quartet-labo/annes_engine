module AnnesIntake
  class DraftAnswer < ApplicationRecord
    belongs_to :step_run, class_name: "AnnesIntake::StepRun"
    belongs_to :field, class_name: "AnnesIntake::Field"
    has_many :values, -> { order(:position) }, class_name: "AnnesIntake::DraftAnswerValue", dependent: :destroy
  end
end
