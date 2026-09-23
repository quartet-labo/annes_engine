module AnnesIntake
  class Form < ApplicationRecord
    before_validation :assign_editor_defaults, on: :create
    def assign_editor_defaults
      self.key = "form_#{SecureRandom.hex(6)}" if key.blank?
    end

    belongs_to :follow_up_request, class_name: "AnnesIntake::FollowUpRequest", optional: true
    scope :templates, -> { where(follow_up_request_id: nil) }
    validate :stable_follow_up_scope, on: :update
    def stable_follow_up_scope
      errors.add(:follow_up_request_id, "は変更できません") if will_save_change_to_follow_up_request_id?
    end
    has_many :versions, class_name: "AnnesIntake::FormVersion", dependent: :restrict_with_exception, inverse_of: :form

    validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z][a-z0-9_]{0,63}\z/ }
    validates :name, presence: true
    validate :key_is_stable, on: :update

    def published_version
      versions.find_by(status: "published")
    end

    private
      def key_is_stable
        errors.add(:key, "は変更できません") if will_save_change_to_key?
      end
  end
end
