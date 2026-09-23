module AnnesIntake
  class Response < ApplicationRecord
    belongs_to :run, class_name: "AnnesIntake::Run"
    has_many :step_responses, class_name: "AnnesIntake::StepResponse", dependent: :restrict_with_exception
    def touch(*) = raise ActiveRecord::ReadOnlyRecord
    before_update { raise ActiveRecord::ReadOnlyRecord }
    before_destroy { raise ActiveRecord::ReadOnlyRecord }
  end
end
