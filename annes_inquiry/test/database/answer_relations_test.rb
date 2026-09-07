require "test_helper"

class AnswerRelationsTest < ActiveSupport::TestCase
  setup do
    form = AnnesInquiry::Form.create!(key: "relations", name: "Relations")
    @version = form.versions.create!(number: 1, title: "Relations")
    @field = @version.fields.create!(key: "kind", label: "Kind", value_type: "single_choice", widget: "select")
    @option = @field.options.create!(value: "one", label: "One")
    @submission = AnnesInquiry::Submission.create!(form_version: @version, payload_digest: "a" * 64)
    @answer = @submission.answers.create!(field: @field, form_version: @version, value_type: "single_choice")
  end

  test "database rejects foreign options and more than one single selection" do
    other_field = @version.fields.create!(key: "other", label: "Other", value_type: "single_choice", widget: "select")
    other_option = other_field.options.create!(value: "two", label: "Two")
    reject_option(field_option_id: other_option.id)
    reject_option(field_id: other_field.id, field_option_id: other_option.id)
    @answer.options.create!(field: @field, field_option: @option, value_type: "single_choice")
    second_option = @field.options.create!(value: "three", label: "Three")
    reject_option(field_option_id: second_option.id)
  end

  test "database rejects attachments under choice answers" do
    assert_raises(ActiveRecord::StatementInvalid) do
      AnnesInquiry::AnswerAttachment.transaction(requires_new: true) do
        AnnesInquiry::AnswerAttachment.insert!({ answer_id: @answer.id, field_id: @field.id, value_type: "attachment", position: 0 })
      end
    end
  end

  test "deleting an attachment reference preserves a shared blob" do
    field = @version.fields.create!(key: "files", label: "Files", value_type: "attachment", widget: "file")
    answer = @submission.answers.create!(field: field, form_version: @version, value_type: "attachment")
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("document"), filename: "document.txt", content_type: "text/plain")
    first = answer.attachments.create!(field: field, value_type: "attachment", position: 0, file: blob)
    second = answer.attachments.create!(field: field, value_type: "attachment", position: 1, file: blob)
    assert_equal [ first.id, second.id ], AnnesInquiry::AnswerReader.new(@submission)["files"].map(&:id)
    first.destroy!
    assert second.reload.file.attached?
    assert_equal "document", second.file.download
    assert ActiveStorage::Blob.exists?(blob.id)
    blob.update!(created_at: 3.days.ago, metadata: { annes_inquiry: true })
    assert_not_includes AnnesInquiry::UnattachedBlobCleanup.candidates.map(&:id), blob.id
  ensure
    second&.destroy!
    blob&.purge
  end

  private
    def reject_option(values)
      assert_raises(ActiveRecord::StatementInvalid) do
        AnnesInquiry::AnswerOption.transaction(requires_new: true) do
          AnnesInquiry::AnswerOption.insert!({ answer_id: @answer.id, field_id: @field.id, value_type: "single_choice", field_option_id: @option.id }.merge(values))
        end
      end
    end
end
