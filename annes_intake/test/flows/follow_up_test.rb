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
  teardown { AnnesIntake.configuration.adapters.clear }

  test "template follow up preserves original and uses dedicated host callback once" do
    request = prepare
    run = issue(request)
    assert_equal run.id, issue(request).id
    assert_equal @root.owner_digest, run.owner_digest
    assert_equal 1, @root.follow_up_requests.count
    run.step_runs.each { |step| save_and_complete(run, step, "Additional") }
    token = token_for(run, :finalize)
    2.times { AnnesIntake::Flows::FinalizeRun.call(run: run, context: @context, token: token) }
    assert request.reload.answered?
    assert_equal 1, FlowIntakeRequest.where(run_id: @root.id).count
    assert_equal 2, @adapter.persisted.size
    assert_equal "Original", AnnesIntake::Flows::AnswerReader.call(run: @root, context: @context).fetch("part_0").fetch("name")
    assert_equal "Additional", AnnesIntake::Flows::AnswerReader.call(run: run.reload, context: @context).fetch("part_0").fetch("name")
    assert_equal 1, @root.notification_requests.where(event_key: "follow_up:#{request.id}:issued").count
    assert_equal 1, run.notification_requests.where(event_key: "answered").count
    assert_equal [request.id], AnnesIntake::Flows::FollowUpReader.call(root: @root, context: @context).map(&:id)
  end

  test "scoped definitions are isolated and cannot be used as regular intake" do
    request = prepare(custom: true)
    version = request.definition_version
    assert_not_equal @template.flow_id, version.flow_id
    assert_equal request.id, version.flow.follow_up_request_id
    assert @template.reload.published?
    version.steps.each { |step| assert_equal request.id, step.form_version.form.follow_up_request_id }
    run = issue(request)
    assert_raises(AnnesIntake::Flows::Forbidden) { AnnesIntake::Flows::StartRun.call(flow: version.flow, context: @context) }
    assert_raises(ActiveRecord::RecordNotSaved) { version.steps.first.form_version.fields.first.update!(label: "Changed") }
    form = version.steps.first.form_version.form
    assert_equal 0, run.step_runs.where.not(step_response_id: nil).count
  end

  test "cancel expiry ownership and host rollback protect additional answers" do
    request = prepare
    run = issue(request)
    assert_raises(ActiveRecord::RecordNotFound) { AnnesIntake::Flows::ResumeRun.call(run: run, context: @context.merge(identity: "bob")) }
    run.step_runs.each { |step| save_and_complete(run, step, "Additional") }
    @adapter.failure = ActiveRecord::Rollback
    assert_raises(AnnesIntake::Flows::Conflict) { finish(run) }
    assert request.reload.issued?
    assert run.reload.in_progress?
    @adapter.failure = nil
    AnnesIntake::Flows::CancelFollowUp.call(request: request, context: @context)
    assert request.reload.cancelled?
    assert_raises(AnnesIntake::Flows::Conflict) { finish(run) }
    assert_equal "Original", AnnesIntake::Flows::AnswerReader.call(run: @root, context: @context).fetch("part_0").fetch("name")
    request2 = prepare
    run2 = issue(request2)
    travel 3.days do
      assert_raises(AnnesIntake::Flows::Conflict) { AnnesIntake::Flows::ResumeRun.call(run: run2, context: @context) }
    end
  end

  test "preparation requires a completed root and matching scope and deduplicates the request key" do
    @root = AnnesIntake::Flows::StartRun.call(flow: @flow, context: @context)
    assert_raises(AnnesIntake::Flows::Conflict) { prepare }
    @root = @run.reload
    request = prepare
    repeated = AnnesIntake::Flows::PrepareFollowUp.call(root: @root, version: @template, context: @context, request_key: request.request_key, title: request.title, due_at: request.due_at)
    assert_equal request.id, repeated.id
    assert_raises(AnnesIntake::Flows::Forbidden) do
      AnnesIntake::Flows::PrepareFollowUp.call(root: @root, version: @template, context: @context.merge(identity: "bob"), request_key: SecureRandom.uuid, title: "Wrong customer", due_at: 2.days.from_now)
    end
    AnnesIntake::Flows::CancelFollowUp.call(request: request, context: @context)
    assert_empty AnnesIntake::Flows::FollowUpReader.call(root: @root, context: @context)
  end

  test "template from another flow uses the original adapter and multiple rounds remain separate" do
    template_flow = AnnesIntake::Flow.create!(key: "question_template", name: "Questions")
    @template = template_flow.versions.create!(number: 1, title: "Questions")
    @version.steps.each { |step| @template.steps.create!(key: step.key, title: step.title, position: step.position, form_version: step.form_version) }
    AnnesIntake::Flows::Definitions::PublishVersion.call(@template, expected_lock_version: 0)
    2.times do |number|
      request = prepare
      response = issue(request)
      response.step_runs.each { |step| save_and_complete(response, step, "Round #{number + 1}") }
      finish(response)
    end
    history = AnnesIntake::Flows::FollowUpReader.call(root: @root, context: @context)
    assert_equal [1, 2], history.map(&:number)
    assert_equal ["Round 1", "Round 2"], history.map { |request| AnnesIntake::Flows::AnswerReader.call(run: request.response_run, context: @context).fetch("part_0").fetch("name") }
    assert_raises(ActiveRecord::RecordNotFound) { AnnesIntake::Flows::FollowUpReader.call(root: @root, context: @context.merge(identity: "bob")) }
    assert_equal 1, FlowIntakeRequest.where(run_id: @root.id).count
    assert_equal 2, FlowFollowUpAnswer.count
  end

  test "a question request key can equal the initial run start key" do
    request = AnnesIntake::Flows::PrepareFollowUp.call(root: @root, version: @template, context: @context, request_key: @root.start_key, title: "Independent key", due_at: 2.days.from_now)
    response = issue(request)
    assert_not_equal @root.start_key, response.start_key
    assert_equal response.id, issue(request).id
  end

  test "private services enforce root scope and prevent exporting cloning or mixing templates" do
    request = prepare(custom: true)
    version = request.definition_version.steps.first.form_version
    private_context = AnnesIntake::DefinitionPolicy::Context.new(definition_context: nil, run_context: @context, follow_up_id: request.id)
    assert_raises(ActiveRecord::RecordNotFound) { AnnesIntake::Definitions::DraftEditor.call(version, expected_lock_version: version.lock_version) { |draft| draft.update!(title: "leak") } }
    assert_raises(AnnesIntake::Flows::Forbidden) { AnnesIntake::Definitions::ExportSchema.call(version: version, context: private_context) }
    assert_raises(AnnesIntake::Flows::Forbidden) { AnnesIntake::Definitions::CloneVersion.call(version, context: private_context) }
    normal = AnnesIntake::Flows::Definitions::CloneVersion.call(@template)
    assert_raises(ActiveRecord::RecordInvalid) { normal.steps.first.update!(form_version: version) }
    AnnesIntake::Definitions::DraftEditor.call(version, expected_lock_version: version.lock_version, context: private_context) { |draft| draft.update!(title: "Private edit") }
    assert_equal "Private edit", version.reload.title
    @adapter.define_singleton_method(:authorize!) { |action:, **| action != :admin_follow_up }
    assert_raises(AnnesIntake::Flows::Forbidden) { AnnesIntake::Definitions::DraftEditor.call(version, expected_lock_version: version.lock_version, context: private_context) { |draft| draft.update!(title: "denied") } }
  end

  test "response scope root stop and root form stop gate additional input" do
    request = prepare(custom: true)
    run = issue(request)
    @flow.update!(enabled: false)
    assert_raises(AnnesIntake::Flows::Conflict) { AnnesIntake::Runs::Resume.call(run: run, context: @context) }
    @flow.update!(enabled: true)
    form = @template.steps.first.form_version.form
    form.update!(enabled: false)
    assert_raises(AnnesIntake::Flows::Conflict) { AnnesIntake::Runs::Resume.call(run: run, context: @context) }
    form.update!(enabled: true)
    @adapter.define_singleton_method(:scope_runs) { |relation, context:| relation.where(id: @only_root) }
    @adapter.instance_variable_set(:@only_root, @root.id)
    assert_raises(ActiveRecord::RecordNotFound) { AnnesIntake::Runs::Resume.call(run: run, context: @context) }
    assert_empty AnnesIntake::FollowUps::Reader.call(root: @root, context: @context)
  end

  test "database rejects duplicate rounds invalid states and wrong response versions" do
    request = prepare
    attrs = request.attributes.except("id", "created_at", "updated_at")
    assert_raises(ActiveRecord::RecordNotUnique) do
      AnnesIntake::ApplicationRecord.transaction(requires_new: true) { AnnesIntake::FollowUpRequest.insert_all!([attrs]) }
    end
    [{number: 0}, {status: "answered"}, {response_run_id: @root.id}].each do |invalid|
      assert_raises(ActiveRecord::StatementInvalid) do
        AnnesIntake::ApplicationRecord.transaction(requires_new: true) { request.update_columns(invalid) }
      end
    end
    request.reload
    private_request = prepare(custom: true)
    other_response = issue(private_request)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      AnnesIntake::ApplicationRecord.transaction(requires_new: true) do
        private_request.reload.update_columns(response_run_id: nil, status: "cancelled")
        request.update_columns(response_run_id: other_response.id, status: "issued", issued_at: Time.current)
      end
    end
  end

  test "history hides even unissued drafts outside root scope and issue honors root form stop" do
    request = prepare(custom: true)
    @adapter.define_singleton_method(:scope_runs) { |relation, context:| relation.none }
    assert_raises(ActiveRecord::RecordNotFound) { AnnesIntake::FollowUps::Reader.call(root: @root, context: @context, action: :admin_view) }
    @adapter.singleton_class.remove_method(:scope_runs)
    @root.flow_version.steps.first.form_version.form.update!(enabled: false)
    assert_raises(AnnesIntake::Flows::Conflict) { issue(request) }
    assert request.reload.draft?
    assert_nil request.response_run_id
  end

  test "first issue reauthorizes source versions for both template and custom questions" do
    original_authorizer = AnnesIntake.configuration.definition_authorizer
    [false, true].each do |custom|
      [AnnesIntake::FlowVersion, AnnesIntake::FormVersion].each do |denied_class|
        request = prepare(custom: custom)
        [:scope, :action].each do |mode|
          authorizer = TestDefinitionAuthorizer.new
          authorizer.define_singleton_method(:scope_definitions) do |relation, context:|
            mode == :scope && relation.klass == denied_class ? relation.none : relation
          end
          authorizer.define_singleton_method(:authorize!) do |action:, record:, context:|
            !(mode == :action && record.is_a?(denied_class))
          end
          AnnesIntake.configuration.definition_authorizer = authorizer
          assert_no_difference(["AnnesIntake::Run.count", "AnnesIntake::NotificationRequest.count"]) do
            assert_raises(mode == :scope ? ActiveRecord::RecordNotFound : AnnesIntake::Flows::Forbidden) { issue(request) }
          end
          assert request.reload.draft?
          assert_nil request.response_run_id
          if custom
            assert request.definition_version.reload.draft?
            assert request.definition_version.steps.all? { |step| step.form_version.draft? }
          end
          AnnesIntake.configuration.definition_authorizer = original_authorizer
        end
        assert issue(request)
      end
    end
  ensure
    AnnesIntake.configuration.definition_authorizer = original_authorizer
  end

  test "issue preserves explicit definition context retired pins and issued retries" do
    original_authorizer = AnnesIntake.configuration.definition_authorizer
    request = prepare
    replacement = AnnesIntake::Flows::Definitions::CloneVersion.call(@template)
    AnnesIntake::Flows::Definitions::PublishVersion.call(replacement, expected_lock_version: replacement.reload.lock_version)
    @template.steps.each do |step|
      replacement_form = AnnesIntake::Definitions::CloneVersion.call(step.form_version)
      AnnesIntake::Definitions::PublishVersion.call(replacement_form, expected_lock_version: replacement_form.reload.lock_version)
    end
    assert @template.reload.retired?
    authorizer = TestDefinitionAuthorizer.new
    authorizer.define_singleton_method(:authorize!) { |action:, record:, context:| context == :definition_admin }
    AnnesIntake.configuration.definition_authorizer = authorizer
    run = AnnesIntake::FollowUps::Issue.call(request: request, context: @context, definition_context: :definition_admin,
      expected_lock_version: request.reload.lock_version, expected_definition_digest: AnnesIntake::FollowUps::DefinitionDigest.call(request))
    assert request.reload.issued?
    assert_equal run.id, issue(request).id
  ensure
    AnnesIntake.configuration.definition_authorizer = original_authorizer
  end

  private
    def prepare(custom: false)
      AnnesIntake::Flows::PrepareFollowUp.call(root: @root, version: @template, context: @context, request_key: SecureRandom.uuid, title: "Additional questions", due_at: 2.days.from_now, custom: custom)
    end
    def issue(request) = AnnesIntake::Flows::IssueFollowUp.call(request: request, context: @context, expected_lock_version: request.reload.lock_version, expected_definition_digest: AnnesIntake::Flows::FollowUpDefinitionDigest.call(request))
    def token_for(run, action, step = nil) = AnnesIntake::Flows::OperationToken.issue(run: run.reload, action: action, step: step, context: @context)
    def save_and_complete(run, step, name)
      AnnesIntake::Flows::SaveDraft.call(run: run, step: step, context: @context, token: token_for(run, :save, step), raw_values: {"name" => name})
      AnnesIntake::Flows::CompleteStep.call(run: run, step: step, context: @context, token: token_for(run, :complete, step))
    end
    def finish(run) = AnnesIntake::Flows::FinalizeRun.call(run: run, context: @context, token: token_for(run, :finalize))
end
