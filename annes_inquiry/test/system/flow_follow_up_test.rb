require "test_helper"
require "action_dispatch/system_test_case"
require_relative "../support/flow_test_support"

class FlowFollowUpSystemTest < ActionDispatch::SystemTestCase
  include FlowTestSupport
  driven_by :selenium, using: :headless_chrome, screen_size: [1280, 1000]
  setup do
    build_flow
    @root = @run
    @run.step_runs.each do |step|
      token = AnnesInquiry::Flows::OperationToken.issue(run: @run.reload, step: step, action: :save, context: @context)
      AnnesInquiry::Flows::SaveDraft.call(run: @run, step: step, context: @context, token: token, raw_values: {"name" => "Original"})
      token = AnnesInquiry::Flows::OperationToken.issue(run: @run.reload, step: step, action: :complete, context: @context)
      AnnesInquiry::Flows::CompleteStep.call(run: @run, step: step, context: @context, token: token)
    end
    token = AnnesInquiry::Flows::OperationToken.issue(run: @run.reload, action: :finalize, context: @context)
    AnnesInquiry::Flows::FinalizeRun.call(run: @run, context: @context, token: token)
    @root.reload
    AnnesInquiry.configuration.flow_endpoints_enabled = true
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { true }
  end
  teardown do
    AnnesInquiry.configuration.flow_endpoints_enabled = false
    AnnesInquiry.configuration.flow_adapters.clear
    AnnesInquiry.configuration.admin_authenticator = nil
    AnnesInquiry.configuration.admin_authorizer = nil
  end

  test "administrator customizes and issues a question and customer resumes answers without overwriting original" do
    visit "/inquiry/admin/flows/#{@flow.id}/runs/#{@root.id}"
    click_link "追加質問を準備"
    fill_in "質問タイトル", with: "Additional details"
    check "この依頼専用に複製して編集する"
    click_button "質問を準備"
    assert_selector "h1", text: "Additional details"
    request = @root.follow_up_requests.sole
    question_path = current_path
    click_link "Part 0の項目を編集"
    click_link "0: Name (name)"
    fill_in "ラベル", with: "Additional name"
    click_button "項目を保存"
    assert_field "ラベル", with: "Additional name"
    visit question_path
    click_link "質問をプレビュー"
    assert_field "Additional name"
    visit question_path
    click_button "追加質問を発行"
    assert_current_path "/inquiry/admin/flows/#{@flow.id}/runs/#{@root.id}"
    assert_text "issued"
    visit "/inquiry/flow_runs/#{@root.id}"
    assert_text "Original"
    assert_text "回答待ち"
    click_link "質問・回答を開く"
    response_run = request.reload.response_run
    click_link "Part 0"
    fill_in "Additional name", with: "Extra"
    click_button "途中保存"
    assert_text "保存しました。"
    click_button "再認可して再開"
    assert_text "再開しました。"
    click_link "Part 0"
    assert_field "Additional name", with: "Extra"
    click_button "保存して次へ"
    assert_current_path "/inquiry/flow_runs/#{response_run.id}"
    click_link "Part 1"
    fill_in "Name", with: "More"
    click_button "保存して次へ"
    assert_current_path "/inquiry/flow_runs/#{response_run.id}"
    click_link "全体の回答を確認"
    assert_selector "h1", text: "回答を確認"
    click_button "正式に送信する"
    assert_selector "h1", text: "受付が完了しました"
    assert_text "Extra"
    click_link "初回の受付・履歴"
    assert_selector "h1", text: "受付が完了しました"
    assert_text "Original"
    assert_text "回答済み"
    assert_no_text "Extra"
    assert_equal 1, FlowIntakeRequest.where(flow_run_id: @root.id).count
    assert_equal 1, FlowFollowUpAnswer.where(follow_up_request_id: request.id).count
  end

  test "template question can be cancelled and history shows its state" do
    visit "/inquiry/admin/flows/#{@flow.id}/runs/#{@root.id}"
    click_link "追加質問を準備"
    fill_in "質問タイトル", with: "Template question"
    click_button "質問を準備"
    assert_selector "h1", text: "Template question"
    click_button "追加質問を発行"
    assert_current_path "/inquiry/admin/flows/#{@flow.id}/runs/#{@root.id}"
    click_link "第1回 Template question"
    click_button "追加質問を取り消す"
    assert_current_path "/inquiry/admin/flows/#{@flow.id}/runs/#{@root.id}"
    visit "/inquiry/flow_runs/#{@root.id}"
    assert_text "取消済み"
    click_link "質問・回答を開く"
    assert_text "取り消されたか、有効期限を過ぎています"
  end
end
