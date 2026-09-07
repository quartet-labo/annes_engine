module AnnesInquiry
  class FormVersion < ApplicationRecord
    belongs_to :form, class_name: "AnnesInquiry::Form", inverse_of: :versions
    has_many :fields, -> { order(:position, :id) }, class_name: "AnnesInquiry::Field", dependent: :destroy, inverse_of: :form_version
    enum :status, { draft: "draft", published: "published", retired: "retired" }, validate: true

    validates :title, :submit_label, presence: true
    validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :form_id }
    before_create :require_initial_draft
    before_update :require_unchanged_identity_and_status
    before_update :require_persisted_draft
    before_destroy :require_persisted_draft

    private
      def require_initial_draft
        return if draft?

        errors.add(:status, "は下書きから開始してください。")
        throw :abort
      end

      def require_unchanged_identity_and_status
        return unless will_save_change_to_form_id? || will_save_change_to_status?

        errors.add(:base, "所属フォームと公開状態は直接変更できません。")
        throw :abort
      end

      def require_persisted_draft
        return if status_in_database == "draft"

        errors.add(:base, "公開済みの版は変更できません。")
        throw :abort
      end
  end
end
