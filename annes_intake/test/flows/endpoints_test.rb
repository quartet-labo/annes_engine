require "test_helper"
require_relative "../support/flow_test_support"

class FlowEndpointsTest < ActionDispatch::IntegrationTest
  include FlowTestSupport
  setup do
    build_flow
    AnnesIntake.configuration.endpoints_enabled = true
  end
  teardown do
    AnnesIntake.configuration.endpoints_enabled = false
    AnnesIntake.configuration.adapters.clear
    AnnesIntake.configuration.admin_authenticator = nil
    AnnesIntake.configuration.admin_authorizer = nil
  end

  test "participant saves and submits the complete flow through protected endpoints" do
    get "/intake/runs/#{@run.id}"
    assert_response :success
    @run.step_runs.order(:id).each_with_index do |step, i|
      get "/intake/runs/#{@run.id}/steps/#{step.id}"
      assert_response :success
      token = css_select("input[name=token]").first["value"]
      patch "/intake/runs/#{@run.id}/steps/#{step.id}", params: {token: token, intake: {name: "Person #{i}"}, advance: "1"}
      assert_response :see_other
    end
    get "/intake/runs/#{@run.id}/review"
    assert_response :success
    assert_select "h1", text: "回答を確認"
    token = css_select("input[name=token]").first["value"]
    post "/intake/runs/#{@run.id}/finalize", params: {token: token}
    assert_response :see_other
    follow_redirect!
    assert_select "h1", text: "受付が完了しました"
    assert_equal 1, @adapter.persisted.size
    AnnesIntake.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesIntake.configuration.admin_authorizer = ->(controller, user) { true }
    get "/intake/admin/runs/#{@run.id}"
    assert_response :success
    assert_select "h2", text: /Part 0/
  end

  test "unknown endpoint configuration and other owners cannot read run or step" do
    AnnesIntake.configuration.endpoints_enabled = false
    get "/intake/runs/#{@run.id}"
    assert_response :not_found
    AnnesIntake.configuration.endpoints_enabled = true
    get "/intake/runs/#{@run.id}", headers: {"X-Flow-Identity" => "bob"}
    assert_response :not_found
    get "/intake/runs/#{@run.id}/steps/#{@run.step_runs.first.id}", headers: {"X-Flow-Identity" => "bob"}
    assert_response :not_found
  end

  test "file validation failures preserve the other posted values" do
    step = @run.step_runs.first
    token = AnnesIntake::Flows::OperationToken.issue(run: @run, step: step, action: :save, context: @context)
    failure = ->(**options) do
      input = AnnesIntake::Input.new(step.form_version, raw_values: {})
      input.errors.add(:base, "ファイル形式が不正です")
      raise AnnesIntake::Flows::InvalidInput.new(input)
    end
    with_save_draft(failure) do
      patch "/intake/runs/#{@run.id}/steps/#{step.id}", params: {token: token, intake: {name: "Keep this value"}}
    end
    assert_response :unprocessable_entity
    assert_select 'input[name="intake[name]"][value="Keep this value"]'
  end

  test "save and advance rejects an intervening save from another tab" do
    step = @run.step_runs.first
    token = AnnesIntake::Flows::OperationToken.issue(run: @run, step: step, action: :save, context: @context)
    original = AnnesIntake::Flows::SaveDraft.method(:call)
    intervening_save = ->(**options) do
      saved = original.call(**options)
      other_token = AnnesIntake::Flows::OperationToken.issue(run: options.fetch(:run).reload, step: step, action: :save, context: options.fetch(:context))
      original.call(**options.merge(token: other_token, raw_values: {"name" => "Other tab"}))
      saved
    end
    with_save_draft(intervening_save) do
      patch "/intake/runs/#{@run.id}/steps/#{step.id}", params: {token: token, intake: {name: "First tab"}, advance: "1"}
    end
    assert_response :conflict
    assert_select 'form[data-intake-unsaved="true"]'
    assert_select 'input[name="intake[name]"][value="First tab"]'
    assert_equal "draft", step.reload.status
    assert_equal "Other tab", AnnesIntake::Flows::DraftReader.call(step)["name"]
  end

  test "view permission does not require cancel permission" do
    @adapter.define_singleton_method(:authorize!) { |action:, **options| action != :cancel }
    get "/intake/runs/#{@run.id}"
    assert_response :success
    assert_select "button", text: "入力を取り消す", count: 0
  end

  test "administration uses both admin access and flow adapter scope" do
    get "/intake/admin/flows"
    assert_response :forbidden
    AnnesIntake.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesIntake.configuration.admin_authorizer = ->(controller, user) { true }
    get "/intake/admin/flows"
    assert_response :success
    get "/intake/admin/runs", params: {from: Date.current.iso8601, to: Date.current.iso8601}
    assert_response :success
    assert_select "a", text: @run.receipt_id
    get "/intake/admin/runs", headers: {"X-Flow-Identity" => "bob"}
    assert_response :success
    assert_select "a", text: @run.receipt_id, count: 0
  end
  test "administration retains flow filter in search and next page" do
    AnnesIntake.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesIntake.configuration.admin_authorizer = ->(controller, user) { true }
    50.times { AnnesIntake::Flows::StartRun.call(flow: @flow, context: @context) }
    get "/intake/admin/runs", params: {flow_id: @flow.id}
    assert_response :success
    assert_select 'input[name="flow_id"]', value: @flow.id.to_s
    assert_select 'a', text: "次のページ" do |links|
      assert_includes links.first["href"], "flow_id=#{@flow.id}"
    end
  end

  private
    def with_save_draft(implementation)
      service = AnnesIntake::Flows::SaveDraft
      original = service.method(:call)
      service.define_singleton_method(:call, implementation)
      yield
    ensure
      service.define_singleton_method(:call, original)
    end

end
