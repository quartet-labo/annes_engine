require "test_helper"

class DefinitionTypesTest < ActiveSupport::TestCase
  test "publishes every supported value type with compatible settings" do
    AnnesInquiry::TypeRegistry::WIDGETS.each do |type, widgets|
      form = AnnesInquiry::Form.create!(key: "form_#{type}", name: type)
      version = form.versions.create!(number: 1, title: type)
      field = version.fields.create!(key: "answer", label: "Answer", value_type: type, widget: widgets.first)
      field.options.create!(value: "one", label: "One") if field.choice?
      if type == "attachment"
        field.update!(max_files: 1, max_file_bytes: 1024)
        field.file_types.create!(extension: ".pdf", content_type: "application/pdf")
      end
      result = AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
      assert result.published?, type
    end
  end

  test "rejects unknown normalizers and rules for another type" do
    form = AnnesInquiry::Form.create!(key: "invalid_settings", name: "Invalid")
    version = form.versions.create!(number: 1, title: "Invalid")
    field = version.fields.create!(key: "name", label: "Name", normalizer_key: "eval")
    assert_raises(AnnesInquiry::Definitions::Error) { AnnesInquiry::Definitions::Validator.new(version).validate! }
    field.update!(normalizer_key: nil, min_numeric: 0)
    assert_raises(AnnesInquiry::Definitions::Error) { AnnesInquiry::Definitions::Validator.new(version).validate! }
  end

  test "rejects invalid lock versions instead of casting them to zero" do
    form = AnnesInquiry::Form.create!(key: "lock_input", name: "Lock")
    version = form.versions.create!(number: 1, title: "Lock")
    assert_raises(ActiveRecord::StaleObjectError) do
      AnnesInquiry::Definitions::DraftEditor.call(version, expected_lock_version: "invalid") { flunk }
    end
  end
  test "required answers must fit configured upper bounds" do
    form = AnnesInquiry::Form.create!(key: "impossible", name: "Impossible")
    version = form.versions.create!(number: 1, title: "Impossible")
    field = version.fields.create!(key: "name", label: "Name", required: true, max_length: 0)
    assert_raises(AnnesInquiry::Definitions::Error) { AnnesInquiry::Definitions::Validator.new(version).validate! }
    field.update!(value_type: "multiple_choice", widget: "checkbox_group", max_length: nil, max_selections: 0)
    field.options.create!(value: "one", label: "One")
    assert_raises(AnnesInquiry::Definitions::Error) { AnnesInquiry::Definitions::Validator.new(version).validate! }
  end

end
