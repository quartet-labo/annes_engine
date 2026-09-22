module AnnesIntake
  class Step < ApplicationRecord
    before_validation :assign_editor_defaults, on: :create
    def assign_editor_defaults
      self.key = "step_#{SecureRandom.hex(6)}" if key.blank?
      self.position = (flow_version.steps.maximum(:position) || -1) + 1 if position.nil?
    end

    include DraftDefinition
    belongs_to :flow_version, class_name: "AnnesIntake::FlowVersion", inverse_of: :steps
    belongs_to :form_version, class_name: "AnnesIntake::FormVersion"
    has_many :condition_groups, class_name: "AnnesIntake::ConditionGroup", dependent: :destroy
    has_many :value_mappings, class_name: "AnnesIntake::ValueMapping", dependent: :destroy
    validates :key, presence: true, uniqueness: { scope: :flow_version_id }, format: { with: /\A[a-z][a-z0-9_]{0,63}\z/ }
    validates :title, presence: true
    validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: :flow_version_id }

    validate :same_definition_scope
    def same_definition_scope
      return unless flow_version && form_version
      errors.add(:form_version, "は別の受付専用です") unless flow_version.flow.follow_up_request_id == form_version.form.follow_up_request_id
    end

    private
      def definition_owner_attribute = :flow_version_id
      def definition_version = flow_version.reload
  end
end
