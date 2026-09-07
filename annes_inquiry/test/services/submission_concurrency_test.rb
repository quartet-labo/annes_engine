require "test_helper"
require "timeout"

class SubmissionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @form = AnnesInquiry::Form.create!(key: "race_#{SecureRandom.hex(6)}", name: "Race")
    @version = @form.versions.create!(number: 1, title: "Race")
    @version.fields.create!(key: "name", label: "Name", required: true)
    AnnesInquiry::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
    @token = AnnesInquiry::SubmissionToken.issue(@version, identity: "sender")
  end

  teardown do
    @threads&.each { |thread| thread.kill if thread.alive? }
    ids = @form.versions.pluck(:id)
    submissions = AnnesInquiry::Submission.where(form_version_id: ids)
    AnnesInquiry::Answer.where(submission_id: submissions.select(:id)).delete_all
    submissions.delete_all
    AnnesInquiry::Field.where(form_version_id: ids).delete_all
    AnnesInquiry::FormVersion.where(id: ids).delete_all
    AnnesInquiry::Form.where(id: @form.id).delete_all
  end

  test "concurrent sends create one receipt and call persistence once" do
    entered, release, persisted = Queue.new, Queue.new, Queue.new
    adapter = Object.new
    adapter.define_singleton_method(:validate_input) { |values, context| entered << true; release.pop; {} }
    adapter.define_singleton_method(:persist!) { |submission, values, context| persisted << submission.id }
    @threads = 2.times.map { Thread.new { ActiveRecord::Base.connection_pool.with_connection { submit(adapter: adapter) } } }
    2.times { Timeout.timeout(10) { entered.pop } }
    2.times { release << true }
    results = @threads.map { |thread| Timeout.timeout(10) { thread.value } }
    assert results.all?(&:success?)
    assert_equal 1, results.map { |item| item.submission.id }.uniq.size
    assert_equal 1, persisted.size
    assert_equal 1, AnnesInquiry::Submission.where(form_version: @version).count
  end

  test "publishing while validation is in progress rejects the stale new submission" do
    entered, release = Queue.new, Queue.new
    adapter = Object.new
    adapter.define_singleton_method(:validate_input) { |values, context| entered << true; release.pop; {} }
    @threads = [ Thread.new { ActiveRecord::Base.connection_pool.with_connection { submit(adapter: adapter) } } ]
    Timeout.timeout(10) { entered.pop }
    draft = AnnesInquiry::Definitions::CloneVersion.call(@version)
    AnnesInquiry::Definitions::PublishVersion.call(draft, expected_lock_version: 0)
    release << true
    assert_equal 409, Timeout.timeout(10) { @threads.first.value }.status
    assert_equal 0, AnnesInquiry::Submission.where(form_version: @version).count
  end

  private
    def submit(adapter:)
      AnnesInquiry::SubmissionService.call(form: @form, token: @token, identity: "sender", raw_values: { "name" => "Alice" }, adapter: adapter)
    end
end
