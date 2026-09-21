module AnnesInquiry
  class DraftAnswer < ApplicationRecord
    belongs_to :step_run, class_name: "AnnesInquiry::StepRun"
    belongs_to :field, class_name: "AnnesInquiry::Field"
    has_many :values, -> { order(:position) }, class_name: "AnnesInquiry::DraftAnswerValue", dependent: :destroy
  end
end
