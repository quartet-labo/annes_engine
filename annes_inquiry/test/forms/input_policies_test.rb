require "test_helper"

class InputPoliciesTest < ActiveSupport::TestCase
  setup do
    form = AnnesInquiry::Form.create!(key: "policies", name: "Policies")
    @version = form.versions.create!(number: 1, title: "Policies")
  end

  test "validates selection membership duplicates and bounds" do
    field = @version.fields.create!(key: "kinds", label: "Kinds", value_type: "multiple_choice", widget: "multi_select", min_selections: 1, max_selections: 1)
    %w[one two].each { |value| field.options.create!(value: value, label: value) }
    [ [ "bad" ], [ "one", "one" ], [ "one", "two" ] ].each { |values| assert_not parse("kinds" => values).valid? }
    input = parse("kinds" => [ "", "one" ])
    assert input.valid?
    assert_equal [ "one" ], input.values["kinds"]
    assert parse({}).valid?, "Optional empty answers do not need to meet a minimum"
  end

  test "checks upload content count size extension and rejects signed blob IDs" do
    field = @version.fields.create!(key: "files", label: "Files", value_type: "attachment", widget: "file", max_files: 1, max_file_bytes: 10)
    field.file_types.create!(extension: ".txt", content_type: "text/plain")
    file = upload("hello", "note.txt")
    assert_no_difference("ActiveStorage::Blob.count") do
      input = parse("files" => [ file ])
      assert input.valid?, input.errors.full_messages.inspect
      assert_equal Digest::SHA256.hexdigest("hello"), input.values["files"].first.checksum
      assert_equal 0, file.tempfile.pos
    end
    assert_not parse("files" => [ file, file ]).valid?
    assert_not parse("files" => [ "signed-blob-id" ]).valid?
    assert_not parse("files" => [ upload("", "empty.txt") ]).valid?
    assert_not parse("files" => [ upload("a" * 11, "large.txt") ]).valid?
    assert_not parse("files" => [ upload("hello", "wrong.exe") ]).valid?
    assert_not parse("files" => [ upload("%PDF-1.7\n", "disguised.txt") ]).valid?
    field.file_types.create!(extension: ".pdf", content_type: "application/pdf")
    field.file_types.create!(extension: ".png", content_type: "image/png")
    assert_not parse("files" => [ upload("hello", "fake.pdf") ]).valid?
    assert_not parse("files" => [ upload("hello", "fake.png") ]).valid?
  end

  test "refines compatible file types and validates text across bounded chunks" do
    require "zip"
    field = @version.fields.create!(key: "files", label: "Files", value_type: "attachment", widget: "file", max_files: 1, max_file_bytes: 300_000)
    field.file_types.create!(extension: ".csv", content_type: "text/csv")
    field.file_types.create!(extension: ".txt", content_type: "text/plain")
    field.file_types.create!(extension: ".docx", content_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    csv = parse("files" => [upload("name,value\nAlice,1\n", "report.csv")])
    assert csv.valid?, csv.errors.full_messages.inspect
    assert_equal "text/csv", csv.values["files"].first.content_type
    archive = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("word/document.xml")
      zip.write("<document/>")
    end.string
    docx = parse("files" => [upload(archive, "document.docx")])
    assert docx.valid?, docx.errors.full_messages.inspect
    assert_not parse("files" => [upload("%PDF-1.7\n", "report.csv")]).valid?
    text = "a" * (64 * 1024 - 1) + "あ" + "z" * (64 * 1024)
    file = upload(text, "large.txt")
    io = file.tempfile
    def io.read(length = nil, *args)
      raise "Unbounded read" unless length && length <= 64 * 1024
      super
    end
    assert parse("files" => [file]).valid?
    assert_equal 0, file.tempfile.pos
    assert_not parse("files" => [upload(text.b + "\xff".b, "invalid.txt")]).valid?
    assert_not parse("files" => [upload(text + "\0", "nul.txt")]).valid?
  end

  test "host validation sees original input before enrichment and typed input afterward" do
    @version.fields.create!(key: "quantity", label: "Quantity", value_type: "integer", widget: "number")
    @version.fields.create!(key: "name", label: "Name", required: true)
    adapter = Object.new
    def adapter.validate_raw_input(raw, context)
      raw["quantity"] == "01" ? { quantity: "は先頭ゼロを使用できません" } : {}
    end
    def adapter.enrich_input(values, context)
      values.merge("name" => context)
    end
    def adapter.validate_input(values, context)
      values["quantity"] && values["quantity"] > 100 ? { quantity: "は100以下にしてください" } : {}
    end
    input = AnnesInquiry::Input.new(@version, raw_values: { "quantity" => "01" }, adapter: adapter, context: "Alice")
    assert_not input.valid?
    assert_equal "Alice", input.values["name"]
    input = AnnesInquiry::Input.new(@version, raw_values: { "quantity" => "101" }, adapter: adapter, context: "Alice")
    assert_not input.valid?
    assert input.errors[:quantity].any?
  end

  teardown do
    @tempfiles&.each(&:close!)
  end

  private
    def upload(content, name)
      file = Tempfile.new("inquiry-upload")
      file.binmode
      file.write(content)
      file.rewind
      (@tempfiles ||= []) << file
      ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: name, type: "text/plain")
    end

    def parse(raw)
      AnnesInquiry::Input.new(@version, raw_values: raw)
    end
end
