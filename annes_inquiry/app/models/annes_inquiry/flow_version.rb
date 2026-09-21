module AnnesInquiry
  class FlowVersion < ApplicationRecord
    belongs_to :flow, class_name: "AnnesInquiry::Flow", inverse_of: :versions
    has_many :steps, -> { order(:position, :id) }, class_name: "AnnesInquiry::FlowStep", dependent: :destroy, inverse_of: :flow_version
    enum :status, { draft: "draft", published: "published", retired: "retired" }, validate: true
    validates :title, presence: true
    validates :number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :flow_id }
    before_create :initial_draft
    before_update :editable
    before_destroy :editable

    private
      def initial_draft
        throw :abort unless draft?
      end

      def editable
        unless status_in_database == "draft" && !will_save_change_to_status? && !will_save_change_to_flow_id?
          errors.add(:base, "公開済みの定義は変更できません。")
          throw :abort
        end
      end
  end
end
