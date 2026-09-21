require "test_helper"
require_relative "../support/flow_test_support"

class FlowEndpointsTest < ActionDispatch::IntegrationTest
  include FlowTestSupport
  setup do
    build_flow
    AnnesInquiry.configuration.flow_endpoints_enabled = true
  end
  teardown do
    AnnesInquiry.configuration.flow_endpoints_enabled = false
    AnnesInquiry.configuration.flow_adapters.clear
    AnnesInquiry.configuration.admin_authenticator = nil
    AnnesInquiry.configuration.admin_authorizer = nil
  end

  test "participant saves and submits the complete flow through protected endpoints" do
    get "/inquiry/flow_runs/#{@run.id}"
    assert_response :success
    @run.step_runs.order(:id).each_with_index do |step, i|
      get "/inquiry/flow_runs/#{@run.id}/steps/#{step.id}"
      assert_response :success
      token = css_select("input[name=token]").first["value"]
      patch "/inquiry/flow_runs/#{@run.id}/steps/#{step.id}", params: {token: token, inquiry: {name: "Person #{i}"}, advance: "1"}
      assert_response :see_other
    end
    get "/inquiry/flow_runs/#{@run.id}/review"
    assert_response :success
    assert_select "h1", text: "回答を確認"
    token = css_select("input[name=token]").first["value"]
    post "/inquiry/flow_runs/#{@run.id}/finalize", params: {token: token}
    assert_response :see_other
    follow_redirect!
    assert_select "h1", text: "受付が完了しました"
    assert_equal 1, @adapter.persisted.size
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { true }
    submission = @run.step_runs.first.submission
    assert_not_includes AnnesInquiry::SubmissionQuery.new.call, submission
    get "/inquiry/admin/submissions/#{submission.id}"
    assert_response :not_found
  end

  test "unknown endpoint configuration and other owners cannot read run or step" do
    AnnesInquiry.configuration.flow_endpoints_enabled = false
    get "/inquiry/flow_runs/#{@run.id}"
    assert_response :not_found
    AnnesInquiry.configuration.flow_endpoints_enabled = true
    get "/inquiry/flow_runs/#{@run.id}", headers: {"X-Flow-Identity" => "bob"}
    assert_response :forbidden
    get "/inquiry/flow_runs/#{@run.id}/steps/#{@run.step_runs.first.id}", headers: {"X-Flow-Identity" => "bob"}
    assert_response :forbidden
  end

  test "file validation failures preserve the other posted values" do
    step = @run.step_runs.first
    token = AnnesInquiry::Flows::OperationToken.issue(run: @run, step: step, action: :save, context: @context)
    failure = ->(**options) do
      input = AnnesInquiry::Input.new(step.form_version, raw_values: {})
      input.errors.add(:base, "ファイル形式が不正です")
      raise AnnesInquiry::Flows::InvalidInput.new(input)
    end
    with_save_draft(failure) do
      patch "/inquiry/flow_runs/#{@run.id}/steps/#{step.id}", params: {token: token, inquiry: {name: "Keep this value"}}
    end
    assert_response :unprocessable_entity
    assert_select 'input[name="inquiry[name]"][value="Keep this value"]'
  end

  test "save and advance rejects an intervening save from another tab" do
    step = @run.step_runs.first
    token = AnnesInquiry::Flows::OperationToken.issue(run: @run, step: step, action: :save, context: @context)
    original = AnnesInquiry::Flows::SaveDraft.method(:call)
    intervening_save = ->(**options) do
      saved = original.call(**options)
      other_token = AnnesInquiry::Flows::OperationToken.issue(run: @run.reload, step: step, action: :save, context: @context)
      original.call(**options.merge(token: other_token, raw_values: {"name" => "Other tab"}))
      saved
    end
    with_save_draft(intervening_save) do
      patch "/inquiry/flow_runs/#{@run.id}/steps/#{step.id}", params: {token: token, inquiry: {name: "First tab"}, advance: "1"}
    end
    assert_response :conflict
    assert_equal "draft", step.reload.status
    assert_equal "Other tab", AnnesInquiry::Flows::DraftReader.call(step)["name"]
  end

  test "view permission does not require cancel permission" do
    @adapter.define_singleton_method(:authorize!) { |action:, **options| action != :cancel }
    get "/inquiry/flow_runs/#{@run.id}"
    assert_response :success
    assert_select "button", text: "入力を取り消す", count: 0
  end

  test "administration uses both admin access and flow adapter scope" do
    get "/inquiry/admin/flows"
    assert_response :forbidden
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { true }
    get "/inquiry/admin/flows"
    assert_response :success
    get "/inquiry/admin/flows/#{@flow.id}/runs", params: {from: Date.current.iso8601, to: Date.current.iso8601}
    assert_response :success
    assert_select "a", text: @run.receipt_id
    get "/inquiry/admin/flows/#{@flow.id}/runs", headers: {"X-Flow-Identity" => "bob"}
    assert_response :success
    assert_select "a", text: @run.receipt_id, count: 0
  end
  private
    def with_save_draft(implementation)
      service = AnnesInquiry::Flows::SaveDraft
      original = service.method(:call)
      service.define_singleton_method(:call, implementation)
      yield
    ensure
      service.define_singleton_method(:call, original)
    end

end
