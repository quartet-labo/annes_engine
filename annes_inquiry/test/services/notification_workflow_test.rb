require "test_helper"
require "timeout"

class NotificationWorkflowTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @form = AnnesInquiry::Form.create!(key: "notify_#{SecureRandom.hex(6)}", name: "Notify")
    @version = @form.versions.create!(number: 1, title: "Notify")
    @version.fields.create!(key: "name", label: "Name")
    AnnesInquiry::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
    @deliveries = Queue.new
    deliveries = @deliveries
    @adapter = Object.new
    @adapter.define_singleton_method(:deliver) { |request| deliveries << request.submission_id; :sent }
    AnnesInquiry.configuration.adapters[@form.key] = @adapter
  end

  teardown do
    @threads&.each { |thread| thread.kill if thread.alive? }
    AnnesInquiry.configuration.adapters.delete(@form.key)
    submissions = AnnesInquiry::Submission.where(form_version_id: @version.id)
    AnnesInquiry::NotificationRequest.where(submission_id: submissions.select(:id)).delete_all
    AnnesInquiry::Answer.where(submission_id: submissions.select(:id)).delete_all
    submissions.delete_all
    AnnesInquiry::Field.where(form_version_id: @version.id).delete_all
    AnnesInquiry::FormVersion.where(id: @version.id).delete_all
    AnnesInquiry::Form.where(id: @form.id).delete_all
  end

  test "dispatches only after the outermost commit and never after rollback" do
    result = nil
    AnnesInquiry::ApplicationRecord.transaction do
      result = submit
      assert result.success?
      assert_equal 0, @deliveries.size
      assert_equal "pending", result.submission.notification_requests.first.status
    end
    assert_equal 1, @deliveries.size
    assert_equal "sent", result.submission.notification_requests.first.reload.status
    AnnesInquiry::ApplicationRecord.transaction do
      submit
      raise ActiveRecord::Rollback
    end
    assert_equal 1, @deliveries.size
    assert_equal 1, AnnesInquiry::Submission.where(form_version_id: @version.id).count
  end

  test "delivery failure and ambiguous exception keep the receipt and do not resend" do
    @adapter.define_singleton_method(:deliver) { |request| :failed }
    first = submit
    assert first.success?
    assert_equal "failed", first.submission.notification_requests.first.status
    @adapter.define_singleton_method(:deliver) { |request| raise IOError, "interrupted" }
    second = submit
    assert second.success?
    request = second.submission.notification_requests.first
    assert_equal "unknown", request.status
    AnnesInquiry::NotificationDispatcher.call(request.id)
    assert_equal 1, request.reload.attempts
  end

  test "claiming pending requests is exclusive and stale processing becomes unknown" do
    submission = AnnesInquiry::Submission.create!(form_version: @version, payload_digest: "a" * 64)
    request = submission.notification_requests.create!(kind: "received")
    entered, release = Queue.new, Queue.new
    @adapter.define_singleton_method(:deliver) { |item| entered << true; release.pop; :sent }
    @threads = [ Thread.new { ActiveRecord::Base.connection_pool.with_connection { AnnesInquiry::NotificationDispatcher.call(request.id) } } ]
    Timeout.timeout(10) { entered.pop }
    AnnesInquiry::NotificationDispatcher.call(request.id)
    assert_equal 1, request.reload.attempts
    release << true
    Timeout.timeout(10) { @threads.first.value }
    assert_equal "sent", request.reload.status
    request.update!(status: "processing", processing_started_at: 2.hours.ago)
    AnnesInquiry::NotificationDispatcher.recover!
    assert_equal "unknown", request.reload.status
    assert_equal 1, request.attempts
  end

  test "replay does not enqueue or send another notification and pending can be recovered" do
    token = AnnesInquiry::SubmissionToken.issue(@version, identity: "sender")
    first = submit(token: token)
    assert_no_difference("AnnesInquiry::NotificationRequest.count") do
      assert_equal first.submission.id, submit(token: token).submission.id
    end
    assert_equal 1, @deliveries.size
    pending = first.submission.notification_requests.create!(kind: "recovery_example")
    AnnesInquiry::NotificationDispatcher.recover!
    assert_equal "sent", pending.reload.status
    assert_equal 2, @deliveries.size
  end

  test "non-joinable outer transactions defer dispatch without recursion" do
    result = nil
    AnnesInquiry::ApplicationRecord.transaction(joinable: false) do
      result = submit
      assert result.success?
      assert_equal 0, @deliveries.size
    end
    assert_equal 1, @deliveries.size
    assert_equal "sent", result.submission.notification_requests.sole.status
    AnnesInquiry::ApplicationRecord.transaction(joinable: false) do
      submit
      assert_equal 1, @deliveries.size
      raise ActiveRecord::Rollback
    end
    assert_equal 1, @deliveries.size
  end

  private
    def submit(token: AnnesInquiry::SubmissionToken.issue(@version, identity: "sender"))
      AnnesInquiry::SubmissionService.call(form: @form, token: token, identity: "sender", raw_values: { "name" => "Alice" })
    end
end
