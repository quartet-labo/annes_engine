require "test_helper"

class SubmissionIdempotencyTest < ActiveSupport::TestCase
  setup do
    @form = AnnesInquiry::Form.create!(key: "idempotency", name: "Idempotency")
    @version = @form.versions.create!(number: 1, title: "Idempotency")
    @version.fields.create!(key: "name", label: "Name", required: true)
    @version.fields.create!(key: "note", label: "Note")
    AnnesInquiry::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
    @token = AnnesInquiry::SubmissionToken.issue(@version, identity: "sender")
  end

  test "same key returns the same receipt even after retirement but changed input conflicts" do
    first = submit
    assert first.success?
    assert_no_difference([ "AnnesInquiry::Submission.count", "AnnesInquiry::Answer.count" ]) do
      second = submit
      assert second.replayed?
      assert_equal first.submission.id, second.submission.id
      assert_equal 409, submit(raw_values: { "name" => "Bob" }).status
      assert_equal 409, submit(raw_values: { "unknown" => "value" }).status
      draft = AnnesInquiry::Definitions::CloneVersion.call(@version)
      AnnesInquiry::Definitions::PublishVersion.call(draft, expected_lock_version: 0)
      assert_equal first.submission.id, submit.submission.id
    end
  end

  test "replay uses original trusted enrichment but still compares client input and context" do
    adapter = Object.new
    def adapter.enrichment_keys(context) = [ "name" ]
    def adapter.enrich_input(values, context) = values.merge("name" => context.fetch(:name))
    def adapter.digest_context(context) = { "account" => context.fetch(:account) }
    options = { adapter: adapter, context: { name: "Original", account: 1 }, raw_values: { "note" => "Hello" } }
    first = submit(**options)
    options[:context] = { name: "Changed", account: 1 }
    assert_equal first.submission.id, submit(**options).submission.id
    assert_equal 409, submit(**options.merge(raw_values: { "note" => "Edited" })).status
    assert_equal 409, submit(**options.merge(context: { name: "Changed", account: 2 })).status
  end

  test "digest orders hashes and choices and uses upload content instead of object identity" do
    value = BigDecimal("1.250000")
    first = AnnesInquiry::PayloadDigest.call({ "b" => false, "a" => value }, identity: "one", context: {})
    second = AnnesInquiry::PayloadDigest.call({ "a" => BigDecimal("1.25"), "b" => false }, identity: "one", context: {})
    assert_equal first, second
    assert_not_equal first, AnnesInquiry::PayloadDigest.call({ "a" => value }, identity: "one", context: {})
  end

  private
    def submit(**options)
      AnnesInquiry::SubmissionService.call(**{ form: @form, token: @token, identity: "sender", raw_values: { "name" => "Alice" } }.merge(options))
    end
end
