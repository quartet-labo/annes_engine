module AnnesInquiry
  module DraftDefinition
    extend ActiveSupport::Concern

    included do
      before_save :require_draft_definition
      before_destroy :require_draft_definition
    end

    private
      def require_draft_definition
        owner_changed = persisted? && will_save_change_to_attribute?(definition_owner_attribute)
        return if !owner_changed && definition_version&.draft?

        errors.add(:base, "公開済みの定義は変更できません。複製した下書きを編集してください。")
        throw :abort
      end
  end
end
