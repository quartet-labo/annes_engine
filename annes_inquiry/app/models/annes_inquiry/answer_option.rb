module AnnesInquiry
  class AnswerOption < ApplicationRecord
    belongs_to :answer, class_name: "AnnesInquiry::Answer", inverse_of: :options
    belongs_to :field, class_name: "AnnesInquiry::Field"
    belongs_to :field_option, class_name: "AnnesInquiry::FieldOption"
    validates :value_type, inclusion: { in: %w[single_choice multiple_choice] }
  end
end
