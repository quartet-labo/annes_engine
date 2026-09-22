module AnnesIntake
  class Answer < ApplicationRecord
    def touch(*) = raise ActiveRecord::ReadOnlyRecord
    before_update { raise ActiveRecord::ReadOnlyRecord }
    before_destroy { raise ActiveRecord::ReadOnlyRecord }

    belongs_to :step_response, class_name: "AnnesIntake::StepResponse", inverse_of: :answers
    belongs_to :field, class_name: "AnnesIntake::Field"
    belongs_to :form_version, class_name: "AnnesIntake::FormVersion"
    has_many :options, class_name: "AnnesIntake::AnswerOption", inverse_of: :answer, dependent: :destroy
    has_many :attachments, -> { order(:position, :id) }, class_name: "AnnesIntake::AnswerAttachment", inverse_of: :answer, dependent: :destroy
    validates :value_type, inclusion: { in: TypeRegistry::WIDGETS.keys }
  end
end
