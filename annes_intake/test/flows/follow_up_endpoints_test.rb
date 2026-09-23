require "test_helper"
require_relative "../support/flow_test_support"

class FlowFollowUpEndpointsTest < ActionDispatch::IntegrationTest
  include FlowTestSupport
  setup do
    build_flow
    @root = @run
    @root.step_runs.each do |step|
      token = AnnesIntake::Flows::OperationToken.issue(run: @root.reload, step: step, action: :save, context: @context)
      AnnesIntake::Flows::SaveDraft.call(run: @root, step: step, context: @context, token: token, raw_values: {"name" => "Original"})
      token = AnnesIntake::Flows::OperationToken.issue(run: @root.reload, step: step, action: :complete, context: @context)
      AnnesIntake::Flows::CompleteStep.call(run: @root, step: step, context: @context, token: token)
    end
    token = AnnesIntake::Flows::OperationToken.issue(run: @root.reload, action: :finalize, context: @context)
    AnnesIntake::Flows::FinalizeRun.call(run: @root, context: @context, token: token)
    @root.reload
    AnnesIntake.configuration.endpoints_enabled = true
    AnnesIntake.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesIntake.configuration.admin_authorizer = ->(controller, user) { true }
    @followup = AnnesIntake::Flows::PrepareFollowUp.call(root: @root, version: @version, context: @context, request_key: SecureRandom.uuid, title: "Private questions", due_at: 2.days.from_now, custom: true)
    @path = "/intake/admin/runs/#{@root.id}/follow_ups/#{@followup.id}"
  end
  teardown do
    AnnesIntake.configuration.endpoints_enabled = false
    AnnesIntake.configuration.adapters.clear
    AnnesIntake.configuration.admin_authenticator = nil
    AnnesIntake.configuration.admin_authorizer = nil
  end

  test "private definitions are hidden from generic lists and require root authorization on direct access" do
    version = @followup.definition_version
    form = version.steps.first.form_version.form
    get "/intake/flows/#{version.flow.key}"
    assert_response :not_found
    get "/intake/admin/flows"
    assert_response :success
    assert_select "a[href='/intake/admin/flows/#{version.flow_id}']", count: 0
    get "/intake/admin/forms"
    assert_select "a[href='/intake/admin/forms/#{form.id}']", count: 0
    @adapter.define_singleton_method(:authorize!) { |action:, **| action != :admin_view }
    get "/intake/admin/flows/#{version.flow_id}"
    assert_response :forbidden
    get "/intake/admin/versions/#{version.steps.first.form_version_id}"
    assert_response :forbidden
    post "#{@path}/issue", params: issue_params
    assert_response :forbidden
  end

  test "issuing detects intervening definition edits and issued definitions stay frozen" do
    stale = issue_params
    field = @followup.definition_version.steps.first.form_version.fields.first
    field.update!(label: "Updated question")
    post "#{@path}/issue", params: stale
    assert_response :conflict
    assert_nil @followup.reload.response_run_id
    post "#{@path}/issue", params: issue_params
    assert_response :see_other
    assert @followup.reload.issued?
    post "#{@path}/issue", params: stale
    assert_response :see_other
    patch "/intake/admin/fields/#{field.id}", params: {lock_version: field.form_version.reload.lock_version, field: {label: "Cannot edit"}}
    assert_response :conflict
    get "/intake/runs/#{@followup.response_run_id}", headers: {"X-Flow-Identity" => "bob"}
    assert_response :not_found
    step = @followup.response_run.step_runs.first
    get "/intake/runs/#{@followup.response_run_id}/steps/#{step.id}/attachments/1", headers: {"X-Flow-Identity" => "bob"}
    assert_response :not_found
    get "/intake/runs/#{@root.id}"
    assert_response :success
    assert_select "a[href='/intake/runs/#{@followup.response_run_id}']"
    post "#{@path}/cancel"
    assert_response :see_other
    assert @followup.reload.cancelled?
  end

  test "invalid custom definitions and deletion of referenced drafts return actionable errors" do
    version = @followup.definition_version.steps.first.form_version
    delete "/intake/admin/versions/#{version.id}", params: {lock_version: version.lock_version}
    assert_response :unprocessable_entity
    assert_match "参照中の版", response.body
    version.fields.first.update!(value_type: "single_choice", widget: "select")
    post "#{@path}/issue", params: issue_params
    assert_response :unprocessable_entity
    assert @followup.reload.draft?
    assert version.reload.draft?
    assert_nil @followup.response_run_id
  end

  test "GET and HEAD share viewing authorization while writes still need editing permission" do
    post "#{@path}/issue", params: issue_params
    assert_response :see_other
    version = @followup.definition_version
    field = version.steps.first.form_version.fields.first
    paths = [
      "/intake/admin/flows/#{version.flow_id}",
      "/intake/admin/forms/#{field.form_version.form_id}",
      "/intake/admin/versions/#{field.form_version_id}",
      "/intake/admin/fields/#{field.id}/edit"
    ]
    @adapter.define_singleton_method(:authorize!) { |action:, **| action != :admin_follow_up }
    paths.each do |path|
      get path
      assert_response :success
      head path
      assert_response :success
      assert_empty response.body
    end
    patch "/intake/admin/fields/#{field.id}", params: {lock_version: field.form_version.lock_version, field: {label: "Changed"}}
    assert_response :forbidden
    assert_equal "Name", field.reload.label
    @adapter.define_singleton_method(:authorize!) { |action:, **| action != :admin_view }
    paths.each do |path|
      head path
      assert_response :forbidden
    end
  end

  test "view and cancellation permissions are separate from issuing" do
    post "#{@path}/issue", params: issue_params
    assert_response :see_other
    @adapter.define_singleton_method(:authorize!) { |action:, **| action != :admin_follow_up }
    get @path
    assert_response :success
    assert_select "button", text: "追加質問を発行", count: 0
    head @path
    assert_response :success
    post "#{@path}/cancel"
    assert_response :see_other
    assert @followup.reload.cancelled?
  end

  test "private editor can add only its owned draft form versions" do
    version = @followup.definition_version
    get "/intake/admin/flows/#{version.flow_id}"
    assert_response :success
    assert_select "a", text: "追加質問へ戻る"
    form = version.steps.first.form_version
    assert_select "select[name='step[form_version_id]'] option[value='#{form.id}']"
    assert_select "select[name='step[form_version_id]'] option[value='#{@version.steps.first.form_version_id}']", count: 0
    patch "/intake/admin/flows/#{version.flow_id}/versions/#{version.id}", params: {lock_version: version.lock_version, step: {title: "More", form_version_id: form.id, position: 2}}
    assert_response :see_other
    assert_equal 3, version.reload.steps.count
  end

  test "issue prepares separate definition context and stops when its hook redirects" do
    original_authorizer = AnnesIntake.configuration.definition_authorizer
    authorizer = TestDefinitionAuthorizer.new
    authorizer.define_singleton_method(:prepare_context) { |controller, admin:| controller.redirect_to("/definition-login") }
    AnnesIntake.configuration.definition_authorizer = authorizer
    assert_no_difference(["AnnesIntake::Run.count", "AnnesIntake::NotificationRequest.count"]) do
      post "#{@path}/issue", params: issue_params
      assert_redirected_to "/definition-login"
    end
    assert @followup.reload.draft?
    authorizer.define_singleton_method(:prepare_context) { |controller, admin:| :definition_admin }
    authorizer.define_singleton_method(:authorize!) { |action:, record:, context:| context == :definition_admin }
    post "#{@path}/issue", params: issue_params
    assert_response :see_other
    assert @followup.reload.issued?
  ensure
    AnnesIntake.configuration.definition_authorizer = original_authorizer
  end

  private
    def issue_params
      {lock_version: @followup.reload.lock_version, definition_digest: AnnesIntake::Flows::FollowUpDefinitionDigest.call(@followup)}
    end
end
