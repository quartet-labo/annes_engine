require "test_helper"

class AnswerReaderTest < ActiveSupport::TestCase
  test "returns typed values including false and zero and original choice labels" do
    form = AnnesInquiry::Form.create!(key: "reader", name: "Reader")
    version = form.versions.create!(number: 1, title: "Reader")
    submission = AnnesInquiry::Submission.create!(form_version: version, payload_digest: "a" * 64)
    { "integer" => 0, "boolean" => false, "decimal" => BigDecimal("12.345678"), "date" => Date.new(2026, 9, 6), "datetime" => Time.utc(2026, 9, 6, 12), "text" => "hello" }.each do |type, value|
      field = version.fields.create!(key: type, label: type, value_type: type, widget: AnnesInquiry::TypeRegistry::WIDGETS.fetch(type).first)
      submission.answers.create!(field: field, form_version: version, value_type: type, "#{type}_value" => value)
    end
    field = version.fields.create!(key: "kind", label: "Original", value_type: "single_choice", widget: "select")
    option = field.options.create!(value: "one", label: "Original option")
    answer = submission.answers.create!(field: field, form_version: version, value_type: "single_choice")
    answer.options.create!(field: field, value_type: "single_choice", field_option: option)
    multi = version.fields.create!(key: "many", label: "Many", value_type: "multiple_choice", widget: "multi_select")
    selected = submission.answers.create!(field: multi, form_version: version, value_type: "multiple_choice")
    [ [ "last", 10 ], [ "first", 0 ] ].each do |value, position|
      item = multi.options.create!(value: value, label: value, position: position)
      selected.options.create!(field: multi, value_type: "multiple_choice", field_option: item)
    end
    AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    draft = AnnesInquiry::Definitions::CloneVersion.call(version)
    draft.fields.find_by!(key: "kind").options.first.update!(label: "Changed option")
    AnnesInquiry::Definitions::PublishVersion.call(draft, expected_lock_version: 0)
    reader = AnnesInquiry::AnswerReader.new(submission)
    assert_equal 0, reader["integer"]
    assert_equal false, reader["boolean"]
    assert_equal BigDecimal("12.345678"), reader["decimal"]
    assert_equal Date.new(2026, 9, 6), reader["date"]
    assert_equal Time.utc(2026, 9, 6, 12), reader["datetime"]
    assert_equal "hello", reader["text"]
    assert_equal "one", reader["kind"]
    assert_equal [ "Original option" ], reader.choice_labels("kind")
    assert_equal [ "first", "last" ], reader["many"]
    assert_nil reader["unanswered"]
  end
end
