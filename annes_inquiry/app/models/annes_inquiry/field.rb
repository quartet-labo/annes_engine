module AnnesInquiry
  class Field < ApplicationRecord
    include DraftDefinition

    TYPES = TypeRegistry::WIDGETS.keys.freeze
    belongs_to :form_version, class_name: "AnnesInquiry::FormVersion", inverse_of: :fields
    has_many :options, -> { order(:position, :id) }, class_name: "AnnesInquiry::FieldOption", dependent: :destroy, inverse_of: :field
    has_many :file_types, class_name: "AnnesInquiry::FieldFileType", dependent: :destroy, inverse_of: :field

    validates :key, presence: true, uniqueness: { scope: :form_version_id }, format: { with: /\A[a-z][a-z0-9_]{0,63}\z/ }
    validates :label, :widget, presence: true
    validates :value_type, inclusion: { in: TYPES }
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :min_length, :max_length, :min_selections, :max_selections,
      numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :max_files, :max_file_bytes, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :min_numeric, :max_numeric, numericality: true, allow_nil: true
    validate :valid_bounds

    def choice?
      %w[single_choice multiple_choice].include?(value_type)
    end

    private
      def definition_owner_attribute
        :form_version_id
      end

      def valid_bounds
        %w[length numeric date datetime selections].each do |kind|
          minimum, maximum = self["min_#{kind}"], self["max_#{kind}"]
          errors.add("max_#{kind}", "は最小値以上にしてください") if minimum && maximum && minimum > maximum
        end
        %w[min_date max_date min_datetime max_datetime].each do |column|
          errors.add(column, "が正しくありません") if self[column].nil? && read_attribute_before_type_cast(column).present?
        end
      end

      def definition_version
        form_version.reload
      end
  end
end
