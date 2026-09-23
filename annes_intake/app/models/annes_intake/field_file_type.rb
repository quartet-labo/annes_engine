module AnnesIntake
  class FieldFileType < ApplicationRecord
    include DraftDefinition
    belongs_to :field, class_name: "AnnesIntake::Field", inverse_of: :file_types
    validates :extension, presence: true, uniqueness: { scope: :field_id }, format: { with: /\A\.[a-z0-9]+\z/ }

    private
      def definition_owner_attribute
        :field_id
      end

      def definition_version
        field.form_version.reload
      end
  end
end
