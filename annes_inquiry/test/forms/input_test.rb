require "test_helper"

class InputTest < ActiveSupport::TestCase
  setup do
    @form = AnnesInquiry::Form.create!(key: "input", name: "Input")
    @version = @form.versions.create!(number: 1, title: "Input")
  end

  test "strictly converts numbers and rejects rounding or overflow" do
    field("integer", widget: "number")
    field("decimal", widget: "number")
    input = parse("integer" => "0", "decimal" => "-12.345678")
    assert input.valid?, input.errors.full_messages.inspect
    assert_equal 0, input.values["integer"]
    assert_equal BigDecimal("-12.345678"), input.values["decimal"]
    [ "12abc", "1.1", "9223372036854775808", "-9223372036854775809" ].each { |value| assert_not parse("integer" => value).valid?, value }
    [ "NaN", "Infinity", "1e3", "1.0000001", "1" + "0" * 19 ].each { |value| assert_not parse("decimal" => value).valid?, value }
    assert parse("integer" => "9223372036854775807", "decimal" => "9999999999999999999.999999").valid?
  end

  test "preserves raw invalid input and rejects unexpected shapes and unknown keys" do
    field("integer", widget: "number")
    input = parse("integer" => "bad")
    assert_not input.valid?
    assert_equal "bad", input.raw_values["integer"]
    assert input.errors[:integer].any?
    [ { "unknown" => "value" }, { "integer" => [] }, { "integer" => {} }, [] ].each { |raw| assert_not parse(raw).valid? }
  end

  test "distinguishes missing boolean from false and consent" do
    boolean = field("boolean", widget: "boolean_radio", required: true)
    assert_not parse({}).valid?
    input = parse("boolean" => "false")
    assert input.valid?
    assert_equal false, input.values["boolean"]
    boolean.update!(must_be_true: true)
    assert_not parse("boolean" => "false").valid?
    assert parse("boolean" => "true").valid?
  end

  test "validates dates and converts a declared local timezone to UTC" do
    field("date", widget: "date")
    field("datetime", widget: "datetime")
    assert_not parse("date" => "2026-02-30").valid?
    assert_not parse("datetime" => "2026-09-06T25:00").valid?
    assert_not parse("datetime" => "2026-09-06T24:00").valid?
    input = AnnesInquiry::Input.new(@version, raw_values: { "datetime" => "2026-09-06T12:30" }, time_zone: "Asia/Tokyo")
    assert input.valid?
    assert_equal Time.utc(2026, 9, 6, 3, 30), input.values["datetime"]
    %w[2026-03-08T02:30 2026-11-01T01:30].each do |local|
      assert_not AnnesInquiry::Input.new(@version, raw_values: { "datetime" => local }, time_zone: "America/New_York").valid?
    end
  end

  test "normalizes text and applies required format and bounds" do
    field("text", widget: "email", required: true, normalizer_key: "trim_downcase", format_key: "email", max_length: 40)
    input = parse("text" => " TEST@Example.com ")
    assert input.valid?
    assert_equal "test@example.com", input.values["text"]
    assert_not parse("text" => "bad").valid?
    assert_not parse("text" => "  ").valid?
  end

  test "rejects NUL text before normalization including optional empty-looking input" do
    field("text", normalizer_key: "trim")
    [ "Alice\0Bob", "\0Alice", "Alice\0", "\0" ].each do |raw|
      input = parse("text" => raw)
      assert_not input.valid?
      assert input.errors[:text].any?
      assert_equal raw, input.raw_values["text"]
    end
    assert parse("text" => "Alice\nBob").valid?
  end

  test "rejects NUL in adapter-enriched text" do
    field("text")
    adapter = Object.new
    adapter.define_singleton_method(:enrich_input) { |_, _| { "text" => "Alice\0Bob" } }
    input = AnnesInquiry::Input.new(@version, raw_values: {}, adapter: adapter)
    assert_not input.valid?
    assert input.errors[:text].any?
  end

  private
    def field(type, **settings)
      @version.fields.create!({ key: type, label: type, value_type: type }.merge(settings))
    end

    def parse(raw)
      AnnesInquiry::Input.new(@version, raw_values: raw)
    end
end
