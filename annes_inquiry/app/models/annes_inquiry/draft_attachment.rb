module AnnesInquiry
  class DraftAttachment < ApplicationRecord
    belongs_to :step_run, class_name: "AnnesInquiry::StepRun"
    belongs_to :field, class_name: "AnnesInquiry::Field"
    has_one_attached :file, dependent: false
  end
end
