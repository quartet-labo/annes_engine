module AnnesIntake
  class StepRun < ApplicationRecord
    belongs_to :run, class_name: "AnnesIntake::Run"
    belongs_to :step, class_name: "AnnesIntake::Step"
    belongs_to :form_version, class_name: "AnnesIntake::FormVersion"
    belongs_to :step_response, class_name: "AnnesIntake::StepResponse", optional: true
    has_many :draft_answers, class_name: "AnnesIntake::DraftAnswer", dependent: :destroy
    has_many :draft_attachments, -> { order(:position, :id) }, class_name: "AnnesIntake::DraftAttachment", dependent: :destroy
    enum :status, { draft: "draft", complete: "complete", inactive: "inactive" }, validate: true
    def key = step.key
  end
end
