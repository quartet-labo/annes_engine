require "test_helper"
require "timeout"
require_relative "../support/flow_test_support"

class FlowConcurrencyTest < ActiveSupport::TestCase
  include FlowTestSupport
  self.use_transactional_tests = false
  setup do
    build_flow
    @run.step_runs.order(:id).each do |step|
      token = AnnesInquiry::Flows::OperationToken.issue(run: @run.reload, step: step, action: :save, context: @context)
      AnnesInquiry::Flows::SaveDraft.call(run: @run, step: step, context: @context, token: token, raw_values: {"name" => "Ready"})
      token = AnnesInquiry::Flows::OperationToken.issue(run: @run.reload, step: step, action: :complete, context: @context)
      AnnesInquiry::Flows::CompleteStep.call(run: @run, step: step, context: @context, token: token)
    end
    @token = AnnesInquiry::Flows::OperationToken.issue(run: @run.reload, action: :finalize, context: @context)
  end
  teardown do
    @threads&.each { |thread| thread.kill if thread.alive? }
    AnnesInquiry.configuration.flow_adapters.clear
    version_ids = @flow.versions.pluck(:id)
    form_version_ids = AnnesInquiry::FlowStep.where(flow_version_id: version_ids).pluck(:form_version_id)
    form_ids = AnnesInquiry::FormVersion.where(id: form_version_ids).pluck(:form_id)
    runs = AnnesInquiry::FlowRun.where(flow_version_id: version_ids)
    steps = AnnesInquiry::StepRun.where(flow_run_id: runs.select(:id))
    submission_ids = steps.where.not(submission_id: nil).pluck(:submission_id)
    answers = AnnesInquiry::DraftAnswer.where(step_run_id: steps.select(:id))
    AnnesInquiry::DraftAnswerValue.where(draft_answer_id: answers.select(:id)).delete_all
    answers.delete_all
    AnnesInquiry::FlowNotificationRequest.where(flow_run_id: runs.select(:id)).delete_all
    FlowFollowUpAnswer.where(flow_run_id: runs.select(:id)).delete_all
    AnnesInquiry::FollowUpRequest.where(root_run_id: runs.select(:id)).delete_all
    FlowIntakeRequest.where(flow_run_id: runs.select(:id)).delete_all
    steps.delete_all
    AnnesInquiry::Answer.where(submission_id: submission_ids).delete_all
    AnnesInquiry::Submission.where(id: submission_ids).delete_all
    runs.delete_all
    AnnesInquiry::FlowStep.where(flow_version_id: version_ids).delete_all
    AnnesInquiry::FlowVersion.where(id: version_ids).delete_all
    @flow.delete
    AnnesInquiry::Field.where(form_version_id: form_version_ids).delete_all
    AnnesInquiry::FormVersion.where(id: form_version_ids).delete_all
    AnnesInquiry::Form.where(id: form_ids).delete_all
  end

  test "concurrent finalization commits one host persistence and one delivery" do
    ready, start = Queue.new, Queue.new
    @threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          submit
        end
      end
    end
    2.times { Timeout.timeout(10) { ready.pop } }
    2.times { start << true }
    results = @threads.map { |thread| Timeout.timeout(15) { thread.value } }
    assert_equal [@run.id], results.map(&:id).uniq
    assert_equal 1, FlowIntakeRequest.where(flow_run_id: @run.id).count
    assert_equal 1, @adapter.persisted.size
    assert_equal 1, @adapter.delivered.size
    assert_equal 1, @run.notification_requests.count
  end

  test "outer rollback never delivers and removes all formal answers" do
    AnnesInquiry::ApplicationRecord.transaction do
      submit
      assert_empty @adapter.delivered
      raise ActiveRecord::Rollback
    end
    assert_equal "in_progress", @run.reload.status
    assert_equal 0, @run.notification_requests.count
    assert @run.step_runs.all? { |step| step.submission_id.nil? }
    assert_empty @adapter.delivered
    assert_equal 0, FlowIntakeRequest.where(flow_run_id: @run.id).count
  end

  test "uncertain notification outcome is not automatically retried" do
    @adapter.define_singleton_method(:deliver) { |request| raise IOError, "interrupted" }
    submit
    request = @run.notification_requests.sole
    assert_equal "unknown", request.status
    AnnesInquiry::Flows::NotificationDispatcher.recover!
    assert_equal 1, request.reload.attempts
  end

  test "concurrent follow up issuance creates one response and one notification" do
    submit
    request = prepare_follow_up
    digest = AnnesInquiry::Flows::FollowUpDefinitionDigest.call(request)
    results = parallel do
      AnnesInquiry::Flows::IssueFollowUp.call(request: request, context: @context, expected_lock_version: request.lock_version, expected_definition_digest: digest)
    end
    assert_equal 1, results.map(&:id).uniq.size
    assert_equal 1, @run.follow_up_requests.count
    assert_equal 1, @run.notification_requests.where(event_key: "follow_up:#{request.id}:issued").count
  end

  test "follow up cancellation and finalization cannot both commit" do
    submit
    request = prepare_follow_up
    response = issue_follow_up(request)
    prepare_response(response)
    token = AnnesInquiry::Flows::OperationToken.issue(run: response.reload, action: :finalize, context: @context)
    parallel do |index|
      begin
        if index.zero?
          AnnesInquiry::Flows::CancelFollowUp.call(request: request, context: @context)
        else
          AnnesInquiry::Flows::FinalizeRun.call(run: response, context: @context, token: token)
        end
      rescue AnnesInquiry::Flows::Conflict
        :conflict
      end
    end
    request.reload
    assert_includes %w[answered cancelled], request.status
    assert_equal request.answered? ? 1 : 0, FlowFollowUpAnswer.where(follow_up_request_id: request.id).count
    assert_equal request.answered? ? "submitted" : "cancelled", response.reload.status
    assert_equal 1, FlowIntakeRequest.where(flow_run_id: @run.id).count
  end

  test "concurrent additional answer replay appends once and sends once" do
    submit
    request = prepare_follow_up
    response = issue_follow_up(request)
    prepare_response(response)
    token = AnnesInquiry::Flows::OperationToken.issue(run: response.reload, action: :finalize, context: @context)
    parallel { AnnesInquiry::Flows::FinalizeRun.call(run: response, context: @context, token: token) }
    assert_equal 1, FlowFollowUpAnswer.where(follow_up_request_id: request.id).count
    assert_equal 1, response.notification_requests.where(event_key: "answered", status: "sent").count
    assert_equal 1, FlowIntakeRequest.where(flow_run_id: @run.id).count
  end

  private
    def parallel(&block)
      ready, start = Queue.new, Queue.new
      @threads = 2.times.map do |index|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            start.pop
            block.call(index)
          end
        end
      end
      2.times { Timeout.timeout(10) { ready.pop } }
      2.times { start << true }
      @threads.map { |thread| Timeout.timeout(20) { thread.value } }
    end

    def prepare_follow_up
      AnnesInquiry::Flows::PrepareFollowUp.call(root: @run, version: @version, context: @context, request_key: SecureRandom.uuid, title: "Follow-up", due_at: 2.days.from_now)
    end

    def issue_follow_up(request)
      AnnesInquiry::Flows::IssueFollowUp.call(request: request, context: @context, expected_lock_version: request.lock_version, expected_definition_digest: AnnesInquiry::Flows::FollowUpDefinitionDigest.call(request))
    end

    def prepare_response(run)
      run.step_runs.each do |step|
        token = AnnesInquiry::Flows::OperationToken.issue(run: run.reload, step: step, action: :save, context: @context)
        AnnesInquiry::Flows::SaveDraft.call(run: run, step: step, context: @context, token: token, raw_values: {"name" => "Additional"})
        token = AnnesInquiry::Flows::OperationToken.issue(run: run.reload, step: step, action: :complete, context: @context)
        AnnesInquiry::Flows::CompleteStep.call(run: run, step: step, context: @context, token: token)
      end
    end
    def submit
      AnnesInquiry::Flows::FinalizeRun.call(run: @run, context: @context, token: @token)
    end
end
