module AnnesInquiry
  class AnswerAttachment < ApplicationRecord
    belongs_to :answer, class_name: "AnnesInquiry::Answer", inverse_of: :attachments
    belongs_to :field, class_name: "AnnesInquiry::Field"
    has_one_attached :file, dependent: false
    validates :value_type, inclusion: { in: [ "attachment" ] }
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
