module AnnesInquiry
  module Definitions
    class CloneVersion
      def self.call(version)
        form = Form.find(version.form_id)
        form.with_lock do
          source = form.versions.find(version.id)
          raise Error, "公開した版から複製してください。" if source.draft?
          raise Error, "すでに下書きがあります。" if form.versions.draft.exists?

          draft = source.dup
          draft.assign_attributes(status: "draft", published_at: nil, number: form.versions.maximum(:number) + 1, lock_version: 0)
          draft.save!
          source.fields.includes(:options, :file_types).each do |field|
            copy = field.dup
            copy.form_version = draft
            copy.save!
            field.options.each { |option| copy.options.create!(option.attributes.except("id", "field_id", "created_at", "updated_at")) }
            field.file_types.each { |type| copy.file_types.create!(type.attributes.except("id", "field_id", "created_at", "updated_at")) }
          end
          draft
        end
      end
    end
  end
end
