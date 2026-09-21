require "test_helper"
require_relative "../support/flow_test_support"

class FlowFollowUpTest < ActiveSupport::TestCase
  include FlowTestSupport
  setup do
    build_flow
    @root = @run
    @run.step_runs.each { |step| save_and_complete(@run, step, "Original") }
    finish(@run)
    @root.reload
    @template = @version

  end
  teardown { AnnesInquiry.configuration.flow_adapters.clear }

  test "template follow up preserves original and uses dedicated host callback once" do
    request = prepare
    run = issue(request)
    assert_equal run.id, issue(request).id
    assert_equal @root.owner_digest, run.owner_digest
    assert_equal 1, @root.follow_up_requests.count
    run.step_runs.each { |step| save_and_complete(run, step, "Additional") }
    token = token_for(run, :finalize)
    2.times { AnnesInquiry::Flows::FinalizeRun.call(run: run, context: @context, token: token) }
    assert request.reload.answered?
    assert_equal 1, FlowIntakeRequest.where(flow_run_id: @root.id).count
    assert_equal 2, @adapter.persisted.size
    assert_equal "Original", AnnesInquiry::Flows::AnswerReader.call(run: @root, context: @context).fetch("part_0").fetch("name")
    assert_equal "Additional", AnnesInquiry::Flows::AnswerReader.call(run: run.reload, context: @context).fetch("part_0").fetch("name")
    assert_equal 1, @root.notification_requests.where(event_key: "follow_up:#{request.id}:issued").count
    assert_equal 1, run.notification_requests.where(event_key: "answered").count
    assert_equal [request.id], AnnesInquiry::Flows::FollowUpReader.call(root: @root, context: @context).map(&:id)
  end

  test "scoped definitions are isolated and cannot be used as regular intake" do
    request = prepare(custom: true)
    version = request.definition_version
    assert_not_equal @template.flow_id, version.flow_id
    assert_equal request.id, version.flow.follow_up_request_id
    assert @template.reload.published?
    version.steps.each { |step| assert_equal request.id, step.form_version.form.follow_up_request_id }
    run = issue(request)
    assert_raises(AnnesInquiry::Flows::Forbidden) { AnnesInquiry::Flows::StartRun.call(flow: version.flow, context: @context) }
    assert_raises(ActiveRecord::RecordNotSaved) { version.steps.first.form_version.fields.first.update!(label: "Changed") }
    form = version.steps.first.form_version.form
    submission_token = AnnesInquiry::SubmissionToken.issue(form.published_version, identity: "alice")
    result = AnnesInquiry::SubmissionService.call(form: form, token: submission_token, identity: "alice", raw_values: {"name" => "Bad"})
    assert_equal 409, result.status
    assert_equal 0, run.step_runs.where.not(submission_id: nil).count
  end

  test "cancel expiry ownership and host rollback protect additional answers" do
    request = prepare
    run = issue(request)
    assert_raises(AnnesInquiry::Flows::Forbidden) { AnnesInquiry::Flows::ResumeRun.call(run: run, context: @context.merge(identity: "bob")) }
    run.step_runs.each { |step| save_and_complete(run, step, "Additional") }
    @adapter.failure = ActiveRecord::Rollback
    assert_raises(AnnesInquiry::Flows::Conflict) { finish(run) }
    assert request.reload.issued?
    assert run.reload.in_progress?
    @adapter.failure = nil
    AnnesInquiry::Flows::CancelFollowUp.call(request: request, context: @context)
    assert request.reload.cancelled?
    assert_raises(AnnesInquiry::Flows::Conflict) { finish(run) }
    assert_equal "Original", AnnesInquiry::Flows::AnswerReader.call(run: @root, context: @context).fetch("part_0").fetch("name")
    request2 = prepare
    run2 = issue(request2)
    travel 3.days do
      assert_raises(AnnesInquiry::Flows::Conflict) { AnnesInquiry::Flows::ResumeRun.call(run: run2, context: @context) }
    end
  end

  test "preparation requires a completed root and matching scope and deduplicates the request key" do
    @root = AnnesInquiry::Flows::StartRun.call(flow: @flow, context: @context)
    assert_raises(AnnesInquiry::Flows::Conflict) { prepare }
    @root = @run.reload
    request = prepare
    repeated = AnnesInquiry::Flows::PrepareFollowUp.call(root: @root, version: @template, context: @context, request_key: request.request_key, title: request.title, due_at: request.due_at)
    assert_equal request.id, repeated.id
    assert_raises(AnnesInquiry::Flows::Forbidden) do
      AnnesInquiry::Flows::PrepareFollowUp.call(root: @root, version: @template, context: @context.merge(identity: "bob"), request_key: SecureRandom.uuid, title: "Wrong customer", due_at: 2.days.from_now)
    end
    AnnesInquiry::Flows::CancelFollowUp.call(request: request, context: @context)
    assert_empty AnnesInquiry::Flows::FollowUpReader.call(root: @root, context: @context)
  end

  test "template from another flow uses the original adapter and multiple rounds remain separate" do
    template_flow = AnnesInquiry::Flow.create!(key: "question_template", name: "Questions")
    @template = template_flow.versions.create!(number: 1, title: "Questions")
    @version.steps.each { |step| @template.steps.create!(key: step.key, title: step.title, position: step.position, form_version: step.form_version) }
    AnnesInquiry::Flows::Definitions::PublishVersion.call(@template, expected_lock_version: 0)
    2.times do |number|
      request = prepare
      response = issue(request)
      response.step_runs.each { |step| save_and_complete(response, step, "Round #{number + 1}") }
      finish(response)
    end
    history = AnnesInquiry::Flows::FollowUpReader.call(root: @root, context: @context)
    assert_equal [1, 2], history.map(&:number)
    assert_equal ["Round 1", "Round 2"], history.map { |request| AnnesInquiry::Flows::AnswerReader.call(run: request.response_run, context: @context).fetch("part_0").fetch("name") }
    assert_raises(AnnesInquiry::Flows::Forbidden) { AnnesInquiry::Flows::FollowUpReader.call(root: @root, context: @context.merge(identity: "bob")) }
    assert_equal 1, FlowIntakeRequest.where(flow_run_id: @root.id).count
    assert_equal 2, FlowFollowUpAnswer.count
  end

  test "a question request key can equal the initial run start key" do
    request = AnnesInquiry::Flows::PrepareFollowUp.call(root: @root, version: @template, context: @context, request_key: @root.start_key, title: "Independent key", due_at: 2.days.from_now)
    response = issue(request)
    assert_not_equal @root.start_key, response.start_key
    assert_equal response.id, issue(request).id
  end

  private
    def prepare(custom: false)
      AnnesInquiry::Flows::PrepareFollowUp.call(root: @root, version: @template, context: @context, request_key: SecureRandom.uuid, title: "Additional questions", due_at: 2.days.from_now, custom: custom)
    end
    def issue(request) = AnnesInquiry::Flows::IssueFollowUp.call(request: request, context: @context, expected_lock_version: request.reload.lock_version, expected_definition_digest: AnnesInquiry::Flows::FollowUpDefinitionDigest.call(request))
    def token_for(run, action, step = nil) = AnnesInquiry::Flows::OperationToken.issue(run: run.reload, action: action, step: step, context: @context)
    def save_and_complete(run, step, name)
      AnnesInquiry::Flows::SaveDraft.call(run: run, step: step, context: @context, token: token_for(run, :save, step), raw_values: {"name" => name})
      AnnesInquiry::Flows::CompleteStep.call(run: run, step: step, context: @context, token: token_for(run, :complete, step))
    end
    def finish(run) = AnnesInquiry::Flows::FinalizeRun.call(run: run, context: @context, token: token_for(run, :finalize))
end
