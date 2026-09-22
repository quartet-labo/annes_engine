module AnnesIntake
  class AnswerAttachment < ApplicationRecord
    # ActiveStorage schedules timestamp touches; the immutable answer needs no timestamp update.
    def touch(*) = true
    before_update { raise ActiveRecord::ReadOnlyRecord }
    before_destroy { raise ActiveRecord::ReadOnlyRecord }

    belongs_to :answer, class_name: "AnnesIntake::Answer", inverse_of: :attachments
    belongs_to :field, class_name: "AnnesIntake::Field"
    has_one_attached :file, dependent: false
    validates :value_type, inclusion: { in: [ "attachment" ] }
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
