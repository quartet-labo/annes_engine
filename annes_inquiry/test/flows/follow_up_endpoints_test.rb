require "test_helper"
require_relative "../support/flow_test_support"

class FlowFollowUpEndpointsTest < ActionDispatch::IntegrationTest
  include FlowTestSupport
  setup do
    build_flow
    @root = @run
    @root.step_runs.each do |step|
      token = AnnesInquiry::Flows::OperationToken.issue(run: @root.reload, step: step, action: :save, context: @context)
      AnnesInquiry::Flows::SaveDraft.call(run: @root, step: step, context: @context, token: token, raw_values: {"name" => "Original"})
      token = AnnesInquiry::Flows::OperationToken.issue(run: @root.reload, step: step, action: :complete, context: @context)
      AnnesInquiry::Flows::CompleteStep.call(run: @root, step: step, context: @context, token: token)
    end
    token = AnnesInquiry::Flows::OperationToken.issue(run: @root.reload, action: :finalize, context: @context)
    AnnesInquiry::Flows::FinalizeRun.call(run: @root, context: @context, token: token)
    @root.reload
    AnnesInquiry.configuration.flow_endpoints_enabled = true
    AnnesInquiry.configuration.public_endpoints_enabled = true
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { true }
    @followup = AnnesInquiry::Flows::PrepareFollowUp.call(root: @root, version: @version, context: @context, request_key: SecureRandom.uuid, title: "Private questions", due_at: 2.days.from_now, custom: true)
    @path = "/inquiry/admin/flows/#{@flow.id}/runs/#{@root.id}/follow_ups/#{@followup.id}"
  end
  teardown do
    AnnesInquiry.configuration.flow_endpoints_enabled = false
    AnnesInquiry.configuration.public_endpoints_enabled = false
    AnnesInquiry.configuration.flow_adapters.clear
    AnnesInquiry.configuration.admin_authenticator = nil
    AnnesInquiry.configuration.admin_authorizer = nil
  end

  test "private definitions are hidden from generic lists and require root authorization on direct access" do
    version = @followup.definition_version
    form = version.steps.first.form_version.form
    get "/inquiry/admin/flows"
    assert_response :success
    assert_select "a[href='/inquiry/admin/flows/#{version.flow_id}']", count: 0
    get "/inquiry/admin/forms"
    assert_select "a[href='/inquiry/admin/forms/#{form.id}']", count: 0
    get "/inquiry/admin/submissions"
    assert_response :success
    assert_select "option[value='#{form.id}']", count: 0
    assert_raises(ArgumentError) { AnnesInquiry::SubmissionQuery.new(form_id: form.id, filters: [{"key" => "name", "value" => "x"}]).call }
    get "/inquiry/forms/#{form.key}"
    assert_response :not_found
    @adapter.define_singleton_method(:authorize!) { |action:, **| action != :admin_view }
    get "/inquiry/admin/flows/#{version.flow_id}"
    assert_response :forbidden
    get "/inquiry/admin/versions/#{version.steps.first.form_version_id}"
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
    patch "/inquiry/admin/fields/#{field.id}", params: {lock_version: field.form_version.reload.lock_version, field: {label: "Cannot edit"}}
    assert_response :conflict
    get "/inquiry/flow_runs/#{@followup.response_run_id}", headers: {"X-Flow-Identity" => "bob"}
    assert_response :forbidden
    step = @followup.response_run.step_runs.first
    get "/inquiry/flow_runs/#{@followup.response_run_id}/steps/#{step.id}/attachments/1", headers: {"X-Flow-Identity" => "bob"}
    assert_response :forbidden
    get "/inquiry/flow_runs/#{@root.id}"
    assert_response :success
    assert_select "a[href='/inquiry/flow_runs/#{@followup.response_run_id}']"
    post "#{@path}/cancel"
    assert_response :see_other
    assert @followup.reload.cancelled?
  end

  test "invalid custom definitions and deletion of referenced drafts return actionable errors" do
    version = @followup.definition_version.steps.first.form_version
    delete "/inquiry/admin/versions/#{version.id}", params: {lock_version: version.lock_version}
    assert_response :unprocessable_entity
    assert_match "参照中の版", response.body
    version.fields.first.update!(value_type: "single_choice", widget: "select")
    post "#{@path}/issue", params: issue_params
    assert_response :unprocessable_entity
    assert @followup.reload.draft?
    assert version.reload.draft?
    assert_nil @followup.response_run_id
  end

  private
    def issue_params
      {lock_version: @followup.reload.lock_version, definition_digest: AnnesInquiry::Flows::FollowUpDefinitionDigest.call(@followup)}
    end
end
