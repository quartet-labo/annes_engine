module AnnesInquiry
  class StepRun < ApplicationRecord
    belongs_to :flow_run, class_name: "AnnesInquiry::FlowRun"
    belongs_to :flow_step, class_name: "AnnesInquiry::FlowStep"
    belongs_to :form_version, class_name: "AnnesInquiry::FormVersion"
    belongs_to :submission, class_name: "AnnesInquiry::Submission", optional: true
    has_many :draft_answers, class_name: "AnnesInquiry::DraftAnswer", dependent: :destroy
    has_many :draft_attachments, -> { order(:position, :id) }, class_name: "AnnesInquiry::DraftAttachment", dependent: :destroy
    enum :status, { draft: "draft", complete: "complete", inactive: "inactive" }, validate: true
    def key = flow_step.key
  end
end
