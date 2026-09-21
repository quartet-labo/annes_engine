module AnnesInquiry
  class FlowStep < ApplicationRecord
    include DraftDefinition
    belongs_to :flow_version, class_name: "AnnesInquiry::FlowVersion", inverse_of: :steps
    belongs_to :form_version, class_name: "AnnesInquiry::FormVersion"
    validates :key, presence: true, uniqueness: { scope: :flow_version_id }, format: { with: /\A[a-z][a-z0-9_]{0,63}\z/ }
    validates :title, presence: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: :flow_version_id }

    private
      def definition_owner_attribute = :flow_version_id
      def definition_version = flow_version.reload
  end
end
