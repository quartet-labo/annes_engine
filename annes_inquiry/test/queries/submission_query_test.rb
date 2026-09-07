require "test_helper"

class SubmissionQueryTest < ActiveSupport::TestCase
  setup do
    @form = AnnesInquiry::Form.create!(key: "search", name: "Search")
    @version = @form.versions.create!(number: 1, title: "Search")
    @count = @version.fields.create!(key: "count", label: "Count", value_type: "integer", widget: "number")
    @kind = @version.fields.create!(key: "kind", label: "Kind", value_type: "multiple_choice", widget: "multi_select")
    @one = @kind.options.create!(value: "one", label: "One")
    @two = @kind.options.create!(value: "two", label: "Two")
    AnnesInquiry::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
    @first = create_submission(10, [ @one, @two ])
    @second = create_submission(20, [ @two ])
  end

  test "combines typed conditions without duplicating multi-choice submissions" do
    query = AnnesInquiry::SubmissionQuery.new(form_id: @form.id, filters: [ { "key" => "count", "operator" => "gte", "value" => "10" }, { "key" => "kind", "operator" => "eq", "value" => "one" } ])
    assert_equal [ @first.id ], query.call.pluck(:id)
    assert_includes query.call.to_sql, "EXISTS"
    assert_equal 2, AnnesInquiry::SubmissionQuery.new(form_id: @form.id, filters: [ { "key" => "kind", "operator" => "eq", "value" => "two" } ]).call.count
  end

  test "supports version period and stable pagination and rejects malformed filters" do
    @first.update!(received_at: Time.utc(2026, 1, 1))
    @second.update!(received_at: Time.utc(2026, 2, 1))
    assert_equal [ @first.id ], AnnesInquiry::SubmissionQuery.new(form_id: @form.id, version_id: @version.id, from: "2026-01-01", to: "2026-01-31").call.pluck(:id)
    assert_equal [ @second.id ], AnnesInquiry::SubmissionQuery.new(page: 1, per_page: 1).call.pluck(:id)
    assert_equal [ @first.id ], AnnesInquiry::SubmissionQuery.new(page: 2, per_page: 1).call.pluck(:id)
    assert_raises(ArgumentError) { AnnesInquiry::SubmissionQuery.new(form_id: @form.id, filters: [ { "key" => "unknown", "value" => "x" } ]).call }
    assert_raises(ArgumentError) { AnnesInquiry::SubmissionQuery.new(form_id: @form.id, filters: [ { "key" => "count", "value" => "12bad" } ]).call }
  end

  test "searches a stable field key across versions" do
    draft = AnnesInquiry::Definitions::CloneVersion.call(@version)
    AnnesInquiry::Definitions::PublishVersion.call(draft, expected_lock_version: 0)
    newer = AnnesInquiry::Submission.create!(form_version: draft, payload_digest: "a" * 64)
    newer.answers.create!(field: draft.fields.find_by!(key: "count"), form_version: draft, value_type: "integer", integer_value: 10)
    result = AnnesInquiry::SubmissionQuery.new(form_id: @form.id, filters: [ { "key" => "count", "operator" => "eq", "value" => "10" } ]).call
    assert_equal [ @first.id, newer.id ].sort, result.pluck(:id).sort
  end

  test "preloads display associations with bounded queries and PostgreSQL can plan the filters" do
    statements = []
    subscriber = ->(event) { statements << event.payload[:sql] unless event.payload[:name] == "SCHEMA" || event.payload[:cached] }
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") do
      AnnesInquiry::SubmissionQuery.new(form_id: @form.id).call.each { |submission| submission.form_version.form.name }
    end
    assert_operator statements.size, :<=, 3
    relation = AnnesInquiry::SubmissionQuery.new(form_id: @form.id, filters: [ { "key" => "count", "value" => "10" } ]).call
    plan = AnnesInquiry::ApplicationRecord.connection.execute("EXPLAIN #{relation.to_sql}").values.flatten.join("\n")
    assert_match(/Scan/, plan)
  end

  test "draft edits do not change historical search types" do
    draft = AnnesInquiry::Definitions::CloneVersion.call(@version)
    draft.fields.find_by!(key: "count").update!(value_type: "attachment", widget: "file")
    assert_equal [ @first.id ], AnnesInquiry::SubmissionQuery.new(form_id: @form.id, filters: [ { "key" => "count", "value" => "10" } ]).call.pluck(:id)
  end

  test "normalizes search values using each released version" do
    form = AnnesInquiry::Form.create!(key: "names", name: "Names")
    version = form.versions.create!(number: 1, title: "Names")
    field = version.fields.create!(key: "name", label: "Name", value_type: "text", widget: "text", normalizer_key: "trim")
    AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    old = AnnesInquiry::Submission.create!(form_version: version, payload_digest: "a" * 64)
    old.answers.create!(field: field, form_version: version, value_type: "text", text_value: "Alice")
    draft = AnnesInquiry::Definitions::CloneVersion.call(version)
    draft.fields.find_by!(key: "name").update!(normalizer_key: "trim_downcase")
    AnnesInquiry::Definitions::PublishVersion.call(draft, expected_lock_version: draft.reload.lock_version)
    newer = AnnesInquiry::Submission.create!(form_version: draft, payload_digest: "a" * 64)
    newer.answers.create!(field: draft.fields.find_by!(key: "name"), form_version: draft, value_type: "text", text_value: "alice")
    assert_equal [ old.id, newer.id ].sort, AnnesInquiry::SubmissionQuery.new(form_id: form.id, filters: [ { "key" => "name", "value" => "Alice" } ]).call.pluck(:id).sort
  end

  private
    def create_submission(count, options)
      submission = AnnesInquiry::Submission.create!(form_version: @version, payload_digest: "a" * 64)
      submission.answers.create!(field: @count, form_version: @version, value_type: "integer", integer_value: count)
      answer = submission.answers.create!(field: @kind, form_version: @version, value_type: "multiple_choice")
      options.each { |option| answer.options.create!(field: @kind, value_type: "multiple_choice", field_option: option) }
      submission
    end
end
