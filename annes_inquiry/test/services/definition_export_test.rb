require "test_helper"

class DefinitionExportTest < ActiveSupport::TestCase
  test "exports published definitions without database identities or private answers" do
    form = AnnesInquiry::Form.create!(key: "export", name: "Export")
    version = form.versions.create!(number: 1, title: "Example")
    field = version.fields.create!(key: "amount", label: "Amount", value_type: "decimal", widget: "number", min_numeric: "0.1", max_numeric: "100")
    assert_raises(AnnesInquiry::Definitions::Error) { AnnesInquiry::Definitions::ExportSchema.call(version: version) }
    AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    data = AnnesInquiry::Definitions::ExportSchema.call(version: version)
    schema = AnnesFormKit::SchemaCodec.load(data)
    assert_equal BigDecimal("0.1"), schema.fields.first.min_numeric
    assert_equal data, AnnesFormKit::SchemaCodec.dump(schema)
    assert_equal %w[form schema_version], JSON.parse(data).keys.sort
    assert_not_includes data, "form_version_id"
    assert_not_includes data, "adapter"
    assert_equal 1, form.versions.count
  end
end
