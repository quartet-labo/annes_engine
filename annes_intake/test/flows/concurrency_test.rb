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
    request_ids = AnnesIntake::FollowUpRequest.where(root_run_id: @run.id).pluck(:id)
    flow_ids = [@flow.id] + AnnesIntake::Flow.where(follow_up_request_id: request_ids).pluck(:id)
    version_ids = AnnesIntake::FlowVersion.where(flow_id: flow_ids).pluck(:id)
    form_version_ids = AnnesIntake::Step.where(flow_version_id: version_ids).pluck(:form_version_id)
    form_ids = AnnesIntake::FormVersion.where(id: form_version_ids).pluck(:form_id)
    runs = AnnesIntake::Run.where(flow_version_id: version_ids)
    steps = AnnesIntake::StepRun.where(run_id: runs.select(:id))
    step_response_ids = steps.where.not(step_response_id: nil).pluck(:step_response_id)
    answers = AnnesIntake::DraftAnswer.where(step_run_id: steps.select(:id))
    AnnesIntake::DraftAnswerValue.where(draft_answer_id: answers.select(:id)).delete_all
    answers.delete_all
    AnnesIntake::NotificationRequest.where(run_id: runs.select(:id)).delete_all
    FlowFollowUpAnswer.where(run_id: runs.select(:id)).delete_all
    AnnesIntake::Form.where(follow_up_request_id: request_ids).update_all(follow_up_request_id: nil)
    AnnesIntake::Flow.where(follow_up_request_id: request_ids).update_all(follow_up_request_id: nil)
    AnnesIntake::FollowUpRequest.where(root_run_id: runs.select(:id)).delete_all
    FlowIntakeRequest.where(run_id: runs.select(:id)).delete_all
    steps.update_all(step_response_id: nil)
    AnnesIntake::Answer.where(step_response_id: step_response_ids).delete_all
    AnnesIntake::StepResponse.where(id: step_response_ids).delete_all
    steps.delete_all
    AnnesIntake::Response.where(run_id: runs.select(:id)).delete_all
    runs.delete_all
    AnnesIntake::Step.where(flow_version_id: version_ids).delete_all
    AnnesIntake::FlowVersion.where(id: version_ids).delete_all
    AnnesIntake::Flow.where(id: flow_ids).delete_all
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

  test "concurrent follow up issuance creates one response and one notification" do
    submit
    request = prepare_follow_up
    digest = AnnesIntake::Flows::FollowUpDefinitionDigest.call(request)
    results = parallel do
      AnnesIntake::Flows::IssueFollowUp.call(request: request, context: @context, expected_lock_version: request.lock_version, expected_definition_digest: digest)
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
    token = AnnesIntake::Flows::OperationToken.issue(run: response.reload, action: :finalize, context: @context)
    parallel do |index|
      begin
        if index.zero?
          AnnesIntake::Flows::CancelFollowUp.call(request: request, context: @context)
        else
          AnnesIntake::Flows::FinalizeRun.call(run: response, context: @context, token: token)
        end
      rescue AnnesIntake::Flows::Conflict
        :conflict
      end
    end
    request.reload
    assert_includes %w[answered cancelled], request.status
    assert_equal request.answered? ? 1 : 0, FlowFollowUpAnswer.where(follow_up_request_id: request.id).count
    assert_equal request.answered? ? "submitted" : "cancelled", response.reload.status
    assert_equal 1, FlowIntakeRequest.where(run_id: @run.id).count
  end

  test "concurrent additional answer replay appends once and sends once" do
    submit
    request = prepare_follow_up
    response = issue_follow_up(request)
    prepare_response(response)
    token = AnnesIntake::Flows::OperationToken.issue(run: response.reload, action: :finalize, context: @context)
    parallel { AnnesIntake::Flows::FinalizeRun.call(run: response, context: @context, token: token) }
    assert_equal 1, FlowFollowUpAnswer.where(follow_up_request_id: request.id).count
    assert_equal 1, response.notification_requests.where(event_key: "answered", status: "sent").count
    assert_equal 1, FlowIntakeRequest.where(run_id: @run.id).count
  end

  test "parallel prepare deduplicates and allocates independent round numbers" do
    submit
    key = SecureRandom.uuid
    due = 2.days.from_now
    results = parallel do
      AnnesIntake::FollowUps::Prepare.call(root: @run, version: @version, context: @context, request_key: key, title: "Same", due_at: due)
    end
    assert_equal 1, results.map(&:id).uniq.size
    rounds = parallel { prepare_follow_up }.map(&:number)
    assert_equal [2, 3], rounds.sort
  end

  test "outer rollback removes follow up issue and prevents delivery" do
    submit
    request = prepare_follow_up
    delivered = @adapter.delivered.dup
    AnnesIntake::ApplicationRecord.transaction do
      issue_follow_up(request)
      assert_equal delivered, @adapter.delivered
      raise ActiveRecord::Rollback
    end
    assert request.reload.draft?
    assert_nil request.response_run_id
    assert_equal delivered, @adapter.delivered
  end

  test "editing a private definition and issue serialize the definition snapshot" do
    submit
    request = AnnesIntake::FollowUps::Prepare.call(root: @run, version: @version, context: @context, request_key: SecureRandom.uuid, title: "Private", due_at: 2.days.from_now, custom: true)
    digest = AnnesIntake::FollowUps::DefinitionDigest.call(request)
    version = request.definition_version.steps.first.form_version
    context = AnnesIntake::DefinitionPolicy::Context.new(definition_context: nil, run_context: @context, follow_up_id: request.id)
    results = parallel do |index|
      begin
        if index.zero?
          AnnesIntake::Definitions::DraftEditor.call(version, context: context, expected_lock_version: version.lock_version) { |draft| draft.fields.first.update!(label: "Changed") }
        else
          AnnesIntake::FollowUps::Issue.call(request: request, context: @context, expected_lock_version: request.lock_version, expected_definition_digest: digest)
        end
        :success
      rescue AnnesIntake::Flows::Conflict
        :conflict
      end
    end
    assert_equal [:conflict, :success], results.sort
    assert_equal request.reload.issued? ? "Name" : "Changed", version.reload.fields.first.label
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
      AnnesIntake::Flows::PrepareFollowUp.call(root: @run, version: @version, context: @context, request_key: SecureRandom.uuid, title: "Follow-up", due_at: 2.days.from_now)
    end

    def issue_follow_up(request)
      AnnesIntake::Flows::IssueFollowUp.call(request: request, context: @context, expected_lock_version: request.lock_version, expected_definition_digest: AnnesIntake::Flows::FollowUpDefinitionDigest.call(request))
    end

    def prepare_response(run)
      run.step_runs.each do |step|
        token = AnnesIntake::Flows::OperationToken.issue(run: run.reload, step: step, action: :save, context: @context)
        AnnesIntake::Flows::SaveDraft.call(run: run, step: step, context: @context, token: token, raw_values: {"name" => "Additional"})
        token = AnnesIntake::Flows::OperationToken.issue(run: run.reload, step: step, action: :complete, context: @context)
        AnnesIntake::Flows::CompleteStep.call(run: run, step: step, context: @context, token: token)
      end
    end
    def submit
      AnnesIntake::Flows::FinalizeRun.call(run: @run, context: @context, token: @token)
    end
end
