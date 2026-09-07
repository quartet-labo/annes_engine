require "test_helper"

class DefinitionTest < ActiveSupport::TestCase
  setup do
    @form = AnnesInquiry::Form.create!(key: "contact", name: "お問い合わせ")
    @version = @form.versions.create!(number: 1, title: "お問い合わせ")
  end

  test "versions cannot bypass publication or move to another form" do
    assert_raises(ActiveRecord::RecordNotSaved) { @version.update!(status: "published") }
    assert @version.reload.draft?
    assert_raises(ActiveRecord::RecordNotSaved) { @version.update!(status: "retired") }
    other = AnnesInquiry::Form.create!(key: "other", name: "Other")
    assert_raises(ActiveRecord::RecordNotSaved) { @version.reload.update!(form: other) }
    assert_equal @form, @version.reload.form
    assert_raises(ActiveRecord::RecordNotSaved) do
      AnnesInquiry::Definitions::DraftEditor.call(@version, expected_lock_version: 0) { |draft| draft.update!(form: other) }
    end
    assert_raises(ActiveRecord::RecordNotSaved) { other.versions.create!(number: 1, title: "Invalid", status: "published") }
  end

  test "stores display and typed validation settings without serialized columns" do
    field = @version.fields.create!(key: "quantity", label: "数量", value_type: "integer", widget: "number",
      placeholder: "例：10", min_numeric: 1, max_numeric: 100, required: true)
    assert_equal "例：10", field.reload.placeholder
    assert_equal BigDecimal("1"), field.min_numeric
    assert_not AnnesInquiry::Field.columns.any? { |column| %i[json jsonb].include?(column.type) }
  end

  test "database rejects duplicate field keys and invalid numeric limits" do
    field = @version.fields.create!(key: "name", label: "お名前", value_type: "text", widget: "text")
    assert_raises(ActiveRecord::RecordNotUnique) do
      AnnesInquiry::Field.transaction(requires_new: true) { AnnesInquiry::Field.insert!(field.attributes.except("id")) }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      AnnesInquiry::Field.transaction(requires_new: true) { field.update_columns(min_numeric: 10, max_numeric: 1) }
    end
  end

  test "database only permits one draft and one published version" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      AnnesInquiry::FormVersion.transaction(requires_new: true) do
        AnnesInquiry::FormVersion.insert!(@version.attributes.except("id").merge("number" => 2))
      end
    end
  end

  test "choices belong to fields and their values are unique" do
    field = @version.fields.create!(key: "kind", label: "種別", value_type: "single_choice", widget: "select")
    field.options.create!(value: "question", label: "ご質問")
    assert_not field.options.new(value: "question", label: "別の表示").valid?
  end
  test "persisted definition owners cannot be reassigned" do
    choice = @version.fields.create!(key: "choice", label: "Choice", value_type: "single_choice", widget: "select")
    option = choice.options.create!(value: "one", label: "One")
    file = @version.fields.create!(key: "file", label: "File", value_type: "attachment", widget: "file", max_files: 1, max_file_bytes: 1024)
    file_type = file.file_types.create!(extension: ".pdf")
    AnnesInquiry::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
    draft = @form.versions.create!(number: 2, title: "Next")
    draft.fields.create!(key: "choice", label: "Choice", value_type: "single_choice", widget: "select")
    draft.fields.create!(key: "file", label: "File", value_type: "attachment", widget: "file")
    assert_raises(ActiveRecord::RecordNotSaved) { choice.update!(form_version: draft, key: "moved_choice") }
    assert_raises(ActiveRecord::RecordNotSaved) { option.update!(field: draft.fields.find_by!(key: "choice")) }
    assert_raises(ActiveRecord::RecordNotSaved) { file_type.update!(field: draft.fields.find_by!(key: "file")) }
    assert_equal 2, @version.fields.count
  end

end
