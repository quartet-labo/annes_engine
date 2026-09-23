require "test_helper"
require_relative "../support/flow_test_support"

class IndependentEngineTest < ActiveSupport::TestCase
  include FlowTestSupport
  setup { build_flow }
  teardown do
    AnnesIntake.configuration.adapters.clear
    AnnesIntake.configuration.definition_authorizer = TestDefinitionAuthorizer.new
  end

  test "boots and stores definitions without the Inquiry gem constant or tables" do
    refute Gem.loaded_specs.key?("annes_inquiry")
    refute Object.const_defined?(:AnnesInquiry)
    assert_empty ActiveRecord::Base.connection.tables.grep(/annes_inquiry/)
    assert AnnesIntake::Engine.isolated?
    assert_equal "0.1.0", AnnesIntake::VERSION
    assert AnnesIntake::Form.new(name: "新しい質問").valid?
  end

  test "definition services fail closed and enforce record scopes" do
    AnnesIntake.configuration.definition_authorizer = nil
    assert_raises(AnnesIntake::Forbidden) { AnnesIntake::Definitions::CloneVersion.call(@version.steps.first.form_version) }
    restricted = TestDefinitionAuthorizer.new
    restricted.define_singleton_method(:scope_definitions) { |relation, context:| relation.none }
    AnnesIntake.configuration.definition_authorizer = restricted
    assert_raises(ActiveRecord::RecordNotFound) { AnnesIntake::Flows::Definitions::CloneVersion.call(@version) }
  end

  test "import creates only an independent draft and rolls back unauthorized ownership" do
    schema = AnnesIntake::Definitions::SchemaAdapter.call(@version.steps.first.form_version)
    document = AnnesFormKit::SchemaCodec.dump(schema)
    copy = AnnesIntake::Definitions::ImportSchema.call(document: document, context: :admin)
    assert copy.draft?
    refute_equal @version.steps.first.form_version.form_id, copy.form_id
    assert_equal "Name", copy.fields.sole.label
    assert_equal document, AnnesFormKit::SchemaCodec.dump(AnnesIntake::Definitions::SchemaAdapter.call(copy))
    restricted = TestDefinitionAuthorizer.new
    restricted.define_singleton_method(:authorize!) { |action:, record:, context:| record.nil? }
    AnnesIntake.configuration.definition_authorizer = restricted
    assert_no_difference "AnnesIntake::Form.count" do
      assert_raises(AnnesIntake::Forbidden) { AnnesIntake::Definitions::ImportSchema.call(document: document, context: :admin) }
    end
  end

  test "resume invalidates old operations without extending the original expiry" do
    first = @run.step_runs.first
    expires = @run.expires_at
    token = AnnesIntake::OperationToken.issue(run: @run, step: first, action: :save, context: @context)
    resumed = AnnesIntake::Runs::Resume.call(run: @run, context: @context)
    assert_equal expires, resumed.expires_at
    assert_equal 1, resumed.token_epoch
    assert_raises(AnnesIntake::Conflict) do
      AnnesIntake::Runs::SaveDraft.call(run: resumed, step: first, context: @context, token: token, raw_values: {"name" => "Old tab"})
    end
  end

  test "public operations return one immutable response with all active step responses" do
    @run.step_runs.order(:id).each do |step|
      token = AnnesIntake::OperationToken.issue(run: @run.reload, step: step, action: :save, context: @context)
      saved = AnnesIntake::Runs::SaveDraft.call(run: @run, step: step, context: @context, token: token, raw_values: {"name" => "Alice"})
      token = AnnesIntake::OperationToken.issue(run: @run.reload, step: step, action: :complete, context: @context)
      AnnesIntake::Runs::CompleteStep.call(run: @run, step: step, context: @context, token: token, expected_revision: saved.revision)
    end
    review = AnnesIntake::Runs::Review.call(run: @run, context: @context)
    assert_equal "Alice", review.answers.fetch("part_0").fetch("name")
    result = AnnesIntake::Runs::Finalize.call(run: @run, context: @context, token: review.token)
    refute result.replayed
    assert_equal 2, result.response.step_responses.count
    replay = AnnesIntake::Runs::Finalize.call(run: @run, context: @context, token: review.token)
    assert replay.replayed
    assert_equal result.response.id, replay.response.id
    another = AnnesIntake::Runs::Start.call(flow: @flow, context: @context, request_key: SecureRandom.uuid)
    step_response = result.response.step_responses.first
    AnnesIntake::ApplicationRecord.transaction(requires_new: true) do
      @run.step_runs.where(step_response_id: step_response.id).update_all(step_response_id: nil)
      assert_raises(ActiveRecord::InvalidForeignKey) do
        another.step_runs.find_by!(form_version_id: step_response.form_version_id).update_columns(step_response_id: step_response.id)
      end
      raise ActiveRecord::Rollback
    end
    assert_raises(ActiveRecord::ReadOnlyRecord) { result.response.touch }
    assert_raises(ActiveRecord::ReadOnlyRecord) { result.response.step_responses.first.answers.first.update!(text_value: "changed") }
    refute AnnesIntake::Flows::DraftCleanup.candidates.exists?(@run.id)
  end

  test "review reruns host validation and rejects an incomplete or newly forbidden request" do
    assert_raises(AnnesIntake::Conflict) { AnnesIntake::Runs::Review.call(run: @run, context: @context) }
    @adapter.define_singleton_method(:authorize!) { |**| false }
    assert_raises(AnnesIntake::Forbidden) { AnnesIntake::Runs::Review.call(run: @run, context: @context) }
  end
  test "publishing cannot include templates outside the definition scope" do
    draft = AnnesIntake::Flows::Definitions::CloneVersion.call(@version)
    policy = TestDefinitionAuthorizer.new
    policy.define_singleton_method(:scope_definitions) { |relation, context:| relation.klass == AnnesIntake::FormVersion ? relation.none : relation }
    AnnesIntake.configuration.definition_authorizer = policy
    assert_raises(ActiveRecord::RecordNotFound) do
      AnnesIntake::Flows::Definitions::PublishVersion.call(draft, expected_lock_version: 0)
    end
    assert draft.reload.draft?
    assert @version.reload.published?
  end

end
