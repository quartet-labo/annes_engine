module AnnesIntake
  class DraftAnswerValue < ApplicationRecord
    belongs_to :draft_answer, class_name: "AnnesIntake::DraftAnswer"
  end
end
