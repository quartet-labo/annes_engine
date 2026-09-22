module AnnesIntake
  class Flow < ApplicationRecord
    before_validation :assign_editor_defaults, on: :create
    def assign_editor_defaults
      self.key = "flow_#{SecureRandom.hex(6)}" if key.blank?
    end

    has_many :versions, class_name: "AnnesIntake::FlowVersion", dependent: :restrict_with_exception, inverse_of: :flow
    validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]{0,63}\z/ }
    validates :name, presence: true
    validate :stable_key, on: :update

    def published_version = versions.find_by(status: "published")

    private
      def stable_key
        errors.add(:key, "は変更できません") if will_save_change_to_key?
      end
  end
end
