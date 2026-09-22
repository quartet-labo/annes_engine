require "minitest/autorun"
require "annes_form_kit"
require "stringio"

class FormKitContractTest < Minitest::Test
  def field(**attributes)
    AnnesFormKit::FieldSpec.new(**{key: "name", label: "Name", value_type: "text", widget: "text"}.merge(attributes))
  end
  def schema(*fields)
    AnnesFormKit::FormSchema.new(title: "Example", fields: fields)
  end

  def test_schema_is_deeply_immutable_and_round_trips_without_database_information
    source = "Option one"
    f = field(value_type: "multiple_choice", widget: "checkbox_group", options: [AnnesFormKit::OptionSpec.new(value: "one", label: source)])
    definition = schema(f)
    source.replace("Changed")
    assert_equal "Option one", definition.fields.first.options.first.label
    assert_raises(FrozenError) { definition.fields << f }
    assert_raises(FrozenError) { f.options.first.label.replace("changed") }
    json = AnnesFormKit::SchemaCodec.dump(definition)
    copy = AnnesFormKit::SchemaCodec.load(json)
    assert_equal json, AnnesFormKit::SchemaCodec.dump(copy)
    refute defined?(ActiveRecord)
    refute defined?(AnnesInquiry)
  end

  def test_codec_rejects_unknown_attributes_versions_invalid_shapes_and_limits
    doc = JSON.parse(AnnesFormKit::SchemaCodec.dump(schema(field)))
    [doc.merge("schema_version" => 2), doc.merge("owner" => 123), doc.merge("form" => []),
     doc.merge("form" => doc["form"].merge("fields" => [JSON.parse('{"key":"x","class":"Object"}')])),
     doc.merge("form" => doc["form"].merge("fields" => Array.new(201) { doc["form"]["fields"].first }))].each do |bad|
      assert_raises(ArgumentError) { AnnesFormKit::SchemaCodec.load(JSON.generate(bad)) }
    end
    assert_raises(ArgumentError) { AnnesFormKit::SchemaCodec.load(" " * (1024 * 1024 + 1)) }
  end

  def test_typed_boundaries_and_false_zero_are_preserved
    converter = AnnesFormKit::ValueConverter
    assert_equal false, converter.call(field: field(value_type: "boolean", widget: "boolean_radio"), raw: "false")
    assert_equal 0, converter.call(field: field(value_type: "integer", widget: "number"), raw: "0")
    assert_raises(ArgumentError) { converter.call(field: field(value_type: "integer", widget: "number"), raw: (2**63).to_s) }
    assert_raises(ArgumentError) { converter.call(field: field(value_type: "date", widget: "date"), raw: "2026-02-30") }
    assert_equal ["one"], converter.call(field: field(value_type: "multiple_choice", widget: "checkbox_group"), raw: ["", "one"])
  end

  def test_shape_and_required_validation_are_distinct
    f = field(required: true)
    assert AnnesFormKit::ShapeValidator.call(schema: schema(f), raw_values: {}).valid?
    refute AnnesFormKit::ValueValidator.call(schema: schema(f), values: {}).valid?
    refute AnnesFormKit::ShapeValidator.call(schema: schema(f), raw_values: {"unknown" => "x"}).valid?
    refute AnnesFormKit::ShapeValidator.call(schema: schema(f), raw_values: {"name" => ["x"]}).valid?
    refute AnnesFormKit::ShapeValidator.call(schema: schema(f), raw_values: {"name" => "a\0"}).valid?
  end

  def test_choices_validate_membership_duplicates_and_present_labels
    f = field(value_type: "multiple_choice", widget: "checkbox_group", options: [AnnesFormKit::OptionSpec.new(value: "one", label: "One")])
    refute AnnesFormKit::ValueValidator.call(schema: schema(f), values: {"name" => ["bad"]}).valid?
    refute AnnesFormKit::ValueValidator.call(schema: schema(f), values: {"name" => ["one", "one"]}).valid?
    assert_equal "One", AnnesFormKit::ValuePresenter.call(field: f, value: ["", "one"])
    assert_equal "未回答", AnnesFormKit::ValuePresenter.call(field: f, value: [])
    assert_equal "いいえ", AnnesFormKit::ValuePresenter.call(field: field(value_type: "boolean"), value: false)
    assert_equal "0", AnnesFormKit::ValuePresenter.call(field: field(value_type: "integer"), value: 0)
  end

  def test_attachment_inspection_never_persists_and_resets_the_io
    f = field(value_type: "attachment", widget: "file", constraints: {"max_files" => 1, "max_file_bytes" => 100}, file_types: [AnnesFormKit::FileTypeSpec.new(extension: ".txt", content_type: "text/plain")])
    source = AnnesFormKit::UploadSource.new(io: StringIO.new("hello"), filename: "note.txt")
    result = AnnesFormKit::AttachmentInspector.call(field: f, uploads: [source])
    assert result.valid?, result.errors.inspect
    assert_equal Digest::SHA256.hexdigest("hello"), result.values.first.checksum
    assert_equal 0, source.io.pos
    assert_equal "text/plain", result.values.first.content_type
    bad = AnnesFormKit::UploadSource.new(io: StringIO.new("%PDF-1.7\n"), filename: "note.txt")
    refute AnnesFormKit::AttachmentInspector.call(field: f, uploads: [bad]).valid?
    refute AnnesFormKit::AttachmentInspector.call(field: f, uploads: [source, source]).valid?
  end
  def test_datetime_schema_uses_non_destructive_utc_conversion
    f = field(value_type: "datetime", widget: "datetime", constraints: {min_datetime: Time.new(2026, 1, 1, 0, 0, 0, "+09:00")})
    copy = AnnesFormKit::SchemaCodec.load(AnnesFormKit::SchemaCodec.dump(schema(f)))
    assert_equal Time.utc(2025, 12, 31, 15), copy.fields.first.min_datetime
  end

  def test_rejects_malformed_display_and_constraints
    base = JSON.parse(AnnesFormKit::SchemaCodec.dump(schema(field)))
    [{"help_text" => {"script" => "run"}}, {"constraints" => {"min_length" => false}},
     {"value_type" => "decimal", "widget" => "number", "constraints" => {"min_numeric" => "NaN"}},
     {"value_type" => "decimal", "widget" => "number", "constraints" => {"max_numeric" => "Infinity"}}].each do |attributes|
      doc = Marshal.load(Marshal.dump(base))
      doc["form"]["fields"][0].merge!(attributes)
      assert_raises(ArgumentError) { AnnesFormKit::SchemaCodec.load(JSON.generate(doc)) }
    end
    base["form"]["submit_label"] = nil
    assert_raises(ArgumentError) { AnnesFormKit::SchemaCodec.load(JSON.generate(base)) }
  end

  def test_renderer_accepts_form_kit_result_and_presenter_removes_html_safety
    f = field
    result = AnnesFormKit::ValueValidator.call(schema: schema(f), values: {"name" => "OK"})
    assert_nil AnnesFormKit::Renderer.field_attributes(f, result, scope: "test")[:aria][:invalid]
    html = AnnesFormKit::ValuePresenter.call(field: f, value: "<script>alert(1)</script>".html_safe)
    refute html.html_safe?
    assert_includes ERB::Util.html_escape(html), "&lt;script&gt;"
    assert_equal "2026-01-01 09:00:00 (Asia/Tokyo)", AnnesFormKit::ValuePresenter.call(field: f, value: Time.utc(2026), time_zone: "Asia/Tokyo")
    upload = AnnesFormKit::UploadSource.new(io: StringIO.new("x"), filename: "<x>.txt")
    assert_equal "<x>.txt", AnnesFormKit::ValuePresenter.call(field: f, value: [upload])
  end
end
