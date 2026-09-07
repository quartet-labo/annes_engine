require "test_helper"

class TypedAnswersTest < ActiveSupport::TestCase
  setup do
    @form = AnnesInquiry::Form.create!(key: "answers", name: "Answers")
    @version = @form.versions.create!(number: 1, title: "Answers")
    @field = @version.fields.create!(key: "count", label: "Count", value_type: "integer", widget: "number")
    @submission = AnnesInquiry::Submission.create!(form_version: @version, payload_digest: "a" * 64)
  end

  test "zero and false are stored as actual values" do
    answer = @submission.answers.create!(field: @field, form_version: @version, value_type: "integer", integer_value: 0)
    assert_equal 0, answer.reload.integer_value
    boolean = @version.fields.create!(key: "accept", label: "Accept", value_type: "boolean", widget: "checkbox")
    assert_equal false, @submission.answers.create!(field: boolean, form_version: @version, value_type: "boolean", boolean_value: false).reload.boolean_value
  end

  test "database rejects wrong value columns and absent scalar values" do
    reject_answer(text_value: "12")
    reject_answer(integer_value: 12, text_value: "12")
    reject_answer({})
    reject_answer(value_type: "text", text_value: "12")
  end

  test "database rejects fields from another version and duplicate answers" do
    other_form = AnnesInquiry::Form.create!(key: "other", name: "Other")
    other_version = other_form.versions.create!(number: 1, title: "Other")
    other_field = other_version.fields.create!(key: "count", label: "Count", value_type: "integer", widget: "number")
    reject_answer(field_id: other_field.id, integer_value: 12)
    reject_answer(form_version_id: other_version.id, field_id: other_field.id, integer_value: 12)
    AnnesInquiry::Answer.insert!(attributes.merge(integer_value: 0))
    reject_answer(integer_value: 1)
  end

  private
    def attributes
      { submission_id: @submission.id, field_id: @field.id, form_version_id: @version.id, value_type: "integer" }
    end

    def reject_answer(values)
      assert_raises(ActiveRecord::StatementInvalid) do
        AnnesInquiry::Answer.transaction(requires_new: true) { AnnesInquiry::Answer.insert!(attributes.merge(values)) }
      end
    end
end
