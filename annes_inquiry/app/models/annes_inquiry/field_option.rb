module AnnesInquiry
  class FieldOption < ApplicationRecord
    include DraftDefinition
    belongs_to :field, class_name: "AnnesInquiry::Field", inverse_of: :options
    validates :value, presence: true, uniqueness: { scope: :field_id }
    validates :label, presence: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    private
      def definition_owner_attribute
        :field_id
      end

      def definition_version
        field.form_version.reload
      end
  end
end
