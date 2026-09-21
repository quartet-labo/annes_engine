module AnnesInquiry
  class DraftAnswerValue < ApplicationRecord
    belongs_to :draft_answer, class_name: "AnnesInquiry::DraftAnswer"
  end
end
