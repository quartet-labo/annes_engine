require "test_helper"

class RuntimeTest < ActiveSupport::TestCase
  class Adapter
    attr_accessor :failure
    attr_reader :persisted, :delivered
    def initialize
      @persisted, @delivered = [], []
    end
    def identity(context) = context.fetch(:identity)
    def context_key(context) = "tenant-1"
    def run_expires_at(context) = 7.days.from_now
    def authorize!(action:, run:, step:, context:)
      raise AnnesIntake::Flows::Forbidden unless context[:allowed]
      true
    end
    def scope_runs(relation, context:) = relation.where(owner_digest: Digest::SHA256.hexdigest(identity(context)))
    def persist!(run, answers, context)
      raise failure if failure
      @persisted << [run.id, answers]
    end
    def deliver(request)
      @delivered << request.id
      :sent
    end
  end

  setup do
    @context = {identity: "alice", allowed: true}
    @adapter = Adapter.new
    @flow = AnnesIntake::Flow.create!(key: "intake", name: "Intake")
    @version = @flow.versions.create!(number: 1, title: "Intake")
    2.times do |i|
      form = AnnesIntake::Form.create!(key: "part_#{i}", name: "Part #{i}")
      version = form.versions.create!(number: 1, title: "Part #{i}")
      version.fields.create!(key: "name", label: "Name", required: true)
      AnnesIntake::Definitions::PublishVersion.call(version, expected_lock_version: 0)
      @version.steps.create!(key: "part_#{i}", title: "Part #{i}", position: i, form_version: version)
    end
    AnnesIntake::Flows::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
    AnnesIntake.configuration.adapters[@flow.key] = @adapter
    @run = AnnesIntake::Flows::StartRun.call(flow: @flow, context: @context, request_key: SecureRandom.uuid)
  end

  teardown do
    AnnesIntake.configuration.adapters.clear
  end

  test "partial drafts never create receipts and sequential completion submits once" do
    first, second = @run.step_runs.order(:id).to_a
    assert_raises(AnnesIntake::Flows::Conflict) { save(second, {"name" => "Later"}) }
    save(first, {})
    assert_empty @adapter.persisted
    assert_equal 0, AnnesIntake::StepResponse.count
    assert_raises(AnnesIntake::Flows::InvalidInput) { complete(first) }
    save(first, {"name" => "First"})
    complete(first)
    save(second, {"name" => "Second"})
    complete(second)
    token = token_for(:finalize)
    result = AnnesIntake::Flows::FinalizeRun.call(run: @run, context: @context, token: token)
    assert result.submitted?
    assert_equal 2, AnnesIntake::StepResponse.count
    assert_equal({"part_0" => {"name" => "First"}, "part_1" => {"name" => "Second"}}, @adapter.persisted.sole.last)
    assert_equal 1, AnnesIntake::NotificationRequest.count
    AnnesIntake::Flows::FinalizeRun.call(run: @run, context: @context, token: token)
    assert_equal 1, @adapter.persisted.size
    assert_equal 1, AnnesIntake::NotificationRequest.count
    assert_equal 1, AnnesIntake::Response.count
  end

  test "identity context and action binding are enforced and resumption needs fresh authorization" do
    first = @run.step_runs.first
    token = token_for(:save, first)
    assert_raises(ActiveRecord::RecordNotFound) do
      AnnesIntake::Flows::SaveDraft.call(run: @run, step: first, context: @context.merge(identity: "bob"), token: token, raw_values: {})
    end
    assert_raises(AnnesIntake::Flows::Conflict) { AnnesIntake::Flows::CompleteStep.call(run: @run, step: first, context: @context, token: token) }
    travel 3.hours do
      assert_raises(AnnesIntake::Flows::Conflict) { AnnesIntake::Flows::SaveDraft.call(run: @run, step: first, context: @context, token: token, raw_values: {}) }
      assert_equal @run.id, AnnesIntake::Flows::ResumeRun.call(run: @run, context: @context).id
    end
    @context[:allowed] = false
    assert_raises(AnnesIntake::Flows::Forbidden) { AnnesIntake::Flows::ResumeRun.call(run: @run, context: @context) }
  end

  test "stale writes conflict and prior changes invalidate later completion" do
    first, second = @run.step_runs.order(:id).to_a
    stale = token_for(:save, first)
    save(first, {"name" => "One"}); complete(first)
    save(second, {"name" => "Two"}); complete(second)
    assert_raises(AnnesIntake::Flows::Conflict) { AnnesIntake::Flows::SaveDraft.call(run: @run, step: first, context: @context, token: stale, raw_values: {}) }
    save(first, {"name" => "Changed"})
    assert_equal "draft", second.reload.status
    assert_raises(AnnesIntake::Flows::Conflict) { AnnesIntake::Flows::FinalizeRun.call(run: @run, context: @context, token: token_for(:finalize)) }
  end

  test "host rollback leaves drafts and no partial receipt or notification" do
    @run.step_runs.order(:id).each { |step| save(step, {"name" => "Valid"}); complete(step) }
    @adapter.failure = ActiveRecord::Rollback
    assert_raises(AnnesIntake::Flows::Conflict) { AnnesIntake::Flows::FinalizeRun.call(run: @run, context: @context, token: token_for(:finalize)) }
    assert_equal 0, AnnesIntake::StepResponse.count
    assert_equal 0, AnnesIntake::NotificationRequest.count
    assert_equal "in_progress", @run.reload.status
    assert_equal 2, AnnesIntake::DraftAnswer.count
  end

  test "retired pinned versions continue but disabling any form blocks mutation" do
    form_version = @version.steps.first.form_version
    draft = AnnesIntake::Definitions::CloneVersion.call(form_version)
    AnnesIntake::Definitions::PublishVersion.call(draft, expected_lock_version: 0)
    save(@run.step_runs.first, {"name" => "Pinned"})
    form_version.form.update!(enabled: false)
    assert_raises(AnnesIntake::Flows::Conflict) { AnnesIntake::Flows::ResumeRun.call(run: @run, context: @context) }
  end

  private
    def token_for(action, step = nil)
      AnnesIntake::Flows::OperationToken.issue(run: @run.reload, step: step, action: action, context: @context)
    end
    def save(step, values)
      AnnesIntake::Flows::SaveDraft.call(run: @run, step: step, context: @context, token: token_for(:save, step), raw_values: values)
    end
    def complete(step)
      AnnesIntake::Flows::CompleteStep.call(run: @run, step: step, context: @context, token: token_for(:complete, step))
    end
end
