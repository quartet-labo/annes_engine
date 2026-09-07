module AnnesInquiry
  class Answer < ApplicationRecord
    belongs_to :submission, class_name: "AnnesInquiry::Submission", inverse_of: :answers
    belongs_to :field, class_name: "AnnesInquiry::Field"
    belongs_to :form_version, class_name: "AnnesInquiry::FormVersion"
    has_many :options, class_name: "AnnesInquiry::AnswerOption", inverse_of: :answer, dependent: :destroy
    has_many :attachments, -> { order(:position, :id) }, class_name: "AnnesInquiry::AnswerAttachment", inverse_of: :answer, dependent: :destroy
    validates :value_type, inclusion: { in: TypeRegistry::WIDGETS.keys }
  end
end
