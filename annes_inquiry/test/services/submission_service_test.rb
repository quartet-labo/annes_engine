require "test_helper"

class SubmissionServiceTest < ActiveSupport::TestCase
  setup do
    @form = AnnesInquiry::Form.create!(key: "submit", name: "Submit")
    @version = @form.versions.create!(number: 1, title: "Submit")
    @version.fields.create!(key: "name", label: "Name", required: true)
    AnnesInquiry::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
    @token = AnnesInquiry::SubmissionToken.issue(@version, identity: "session-one")
  end

  test "saves typed answers with a signed version and identity" do
    result = submit
    assert result.success?
    assert_equal "Alice", AnnesInquiry::AnswerReader.new(result.submission)["name"]
    assert_equal @version.id, result.submission.form_version_id
  end

  test "rejects missing invalid expired and foreign identity tokens" do
    [ nil, [], {}, "fake", @token + "tamper" ].each { |token| assert_equal 409, submit(token: token).status }
    assert_equal 409, submit(identity: "other-session").status
    travel 3.hours do
      assert_equal 409, submit.status
    end
    assert_equal 0, AnnesInquiry::Submission.count
  end

  test "rejects retired versions and stopped forms and retains input errors" do
    result = submit(raw_values: { "name" => "" })
    assert_equal 422, result.status
    assert result.input.errors[:name].any?
    @form.update!(enabled: false)
    assert_equal 409, submit.status
    @form.update!(enabled: true)
    draft = AnnesInquiry::Definitions::CloneVersion.call(@version)
    AnnesInquiry::Definitions::PublishVersion.call(draft, expected_lock_version: 0)
    result = submit
    assert_equal 409, result.status
    assert_equal "Alice", result.input.raw_values["name"]
    assert_equal 0, AnnesInquiry::Submission.count
  end

  test "host persistence shares the transaction and rolls everything back on failure" do
    adapter = Object.new
    def adapter.persist!(submission, values, context)
      AnnesInquiry::Form.create!(key: "dummy_business", name: values.fetch("name"))
      raise "business write failed"
    end
    assert_no_difference([ "AnnesInquiry::Submission.count", "AnnesInquiry::Answer.count", "AnnesInquiry::Form.count" ]) do
      assert_raises(RuntimeError) { submit(adapter: adapter) }
    end
  end

  test "an explicit adapter rollback never returns a successful receipt" do
    adapter = Object.new
    def adapter.persist!(submission, values, context)
      raise ActiveRecord::Rollback
    end
    assert_no_difference("AnnesInquiry::Submission.count") do
      result = submit(adapter: adapter)
      assert_not result.success?
      assert_equal 422, result.status
      assert result.input.errors[:base].any?
    end
  end

  private
    def submit(**options)
      AnnesInquiry::SubmissionService.call(**{ form: @form, token: @token, identity: "session-one", raw_values: { "name" => "Alice" } }.merge(options))
    end
end
