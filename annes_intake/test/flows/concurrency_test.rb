require "test_helper"
require "timeout"
require_relative "../support/flow_test_support"

class FlowConcurrencyTest < ActiveSupport::TestCase
  include FlowTestSupport
  self.use_transactional_tests = false
  setup do
    build_flow
    @run.step_runs.order(:id).each do |step|
      token = AnnesIntake::Flows::OperationToken.issue(run: @run.reload, step: step, action: :save, context: @context)
      AnnesIntake::Flows::SaveDraft.call(run: @run, step: step, context: @context, token: token, raw_values: {"name" => "Ready"})
      token = AnnesIntake::Flows::OperationToken.issue(run: @run.reload, step: step, action: :complete, context: @context)
      AnnesIntake::Flows::CompleteStep.call(run: @run, step: step, context: @context, token: token)
    end
    @token = AnnesIntake::Flows::OperationToken.issue(run: @run.reload, action: :finalize, context: @context)
  end
  teardown do
    @threads&.each { |thread| thread.kill if thread.alive? }
    AnnesIntake.configuration.adapters.clear
    version_ids = @flow.versions.pluck(:id)
    form_version_ids = AnnesIntake::Step.where(flow_version_id: version_ids).pluck(:form_version_id)
    form_ids = AnnesIntake::FormVersion.where(id: form_version_ids).pluck(:form_id)
    runs = AnnesIntake::Run.where(flow_version_id: version_ids)
    steps = AnnesIntake::StepRun.where(run_id: runs.select(:id))
    step_response_ids = steps.where.not(step_response_id: nil).pluck(:step_response_id)
    answers = AnnesIntake::DraftAnswer.where(step_run_id: steps.select(:id))
    AnnesIntake::DraftAnswerValue.where(draft_answer_id: answers.select(:id)).delete_all
    answers.delete_all
    AnnesIntake::NotificationRequest.where(run_id: runs.select(:id)).delete_all
    FlowIntakeRequest.where(run_id: runs.select(:id)).delete_all
    steps.update_all(step_response_id: nil)
    AnnesIntake::Answer.where(step_response_id: step_response_ids).delete_all
    AnnesIntake::StepResponse.where(id: step_response_ids).delete_all
    steps.delete_all
    AnnesIntake::Response.where(run_id: runs.select(:id)).delete_all
    runs.delete_all
    AnnesIntake::Step.where(flow_version_id: version_ids).delete_all
    AnnesIntake::FlowVersion.where(id: version_ids).delete_all
    @flow.delete
    AnnesIntake::Field.where(form_version_id: form_version_ids).delete_all
    AnnesIntake::FormVersion.where(id: form_version_ids).delete_all
    AnnesIntake::Form.where(id: form_ids).delete_all
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
    assert_equal 1, FlowIntakeRequest.where(run_id: @run.id).count
    assert_equal 1, @adapter.persisted.size
    assert_equal 1, @adapter.delivered.size
    assert_equal 1, @run.notification_requests.count
  end

  test "outer rollback never delivers and removes all formal answers" do
    AnnesIntake::ApplicationRecord.transaction do
      submit
      assert_empty @adapter.delivered
      raise ActiveRecord::Rollback
    end
    assert_equal "in_progress", @run.reload.status
    assert_equal 0, @run.notification_requests.count
    assert @run.step_runs.all? { |step| step.step_response_id.nil? }
    assert_empty @adapter.delivered
    assert_equal 0, FlowIntakeRequest.where(run_id: @run.id).count
  end

  test "uncertain notification outcome is not automatically retried" do
    @adapter.define_singleton_method(:deliver) { |request| raise IOError, "interrupted" }
    submit
    request = @run.notification_requests.sole
    assert_equal "unknown", request.status
    AnnesIntake::Flows::NotificationDispatcher.recover!
    assert_equal 1, request.reload.attempts
  end

  private
    def submit
      AnnesIntake::Flows::FinalizeRun.call(run: @run, context: @context, token: @token)
    end
end
