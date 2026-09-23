module AnnesIntake
  class AnswerOption < ApplicationRecord
    def touch(*) = raise ActiveRecord::ReadOnlyRecord
    before_update { raise ActiveRecord::ReadOnlyRecord }
    before_destroy { raise ActiveRecord::ReadOnlyRecord }

    belongs_to :answer, class_name: "AnnesIntake::Answer", inverse_of: :options
    belongs_to :field, class_name: "AnnesIntake::Field"
    belongs_to :field_option, class_name: "AnnesIntake::FieldOption"
    validates :value_type, inclusion: { in: %w[single_choice multiple_choice] }
  end
end
