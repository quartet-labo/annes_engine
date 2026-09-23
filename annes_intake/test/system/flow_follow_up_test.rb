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
      token = AnnesIntake::Flows::OperationToken.issue(run: @run.reload, step: step, action: :save, context: @context)
      AnnesIntake::Flows::SaveDraft.call(run: @run, step: step, context: @context, token: token, raw_values: {"name" => "Original"})
      token = AnnesIntake::Flows::OperationToken.issue(run: @run.reload, step: step, action: :complete, context: @context)
      AnnesIntake::Flows::CompleteStep.call(run: @run, step: step, context: @context, token: token)
    end
    token = AnnesIntake::Flows::OperationToken.issue(run: @run.reload, action: :finalize, context: @context)
    AnnesIntake::Flows::FinalizeRun.call(run: @run, context: @context, token: token)
    @root.reload
    AnnesIntake.configuration.endpoints_enabled = true
    AnnesIntake.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesIntake.configuration.admin_authorizer = ->(controller, user) { true }
  end
  teardown do
    AnnesIntake.configuration.endpoints_enabled = false
    AnnesIntake.configuration.adapters.clear
    AnnesIntake.configuration.admin_authenticator = nil
    AnnesIntake.configuration.admin_authorizer = nil
  end

  test "administrator customizes and issues a question and customer resumes answers without overwriting original" do
    visit "/intake/admin/runs/#{@root.id}"
    navigate { click_link "追加質問を準備" }
    fill_in "質問タイトル", with: "Additional details"
    check "この依頼専用に複製して編集する"
    navigate { click_button "質問を準備" }
    assert_selector "h1", text: "Additional details"
    request = @root.follow_up_requests.sole
    question_path = current_path
    navigate { click_link "Part 0の項目を編集" }
    navigate { click_link "Name" }
    fill_in "ラベル", with: "Additional name"
    navigate { click_button "項目を保存" }
    assert_field "ラベル", with: "Additional name"
    visit question_path
    navigate { click_link "質問をプレビュー" }
    assert_field "Additional name"
    visit question_path
    navigate { click_button "追加質問を発行" }
    assert_current_path "/intake/admin/runs/#{@root.id}"
    assert_text "回答待ち"
    visit "/intake/runs/#{@root.id}"
    assert_text "Original"
    assert_text "回答待ち"
    navigate { click_link "質問・回答を開く" }
    response_run = request.reload.response_run
    navigate { click_link "Part 0" }
    fill_in "Additional name", with: "Extra"
    navigate { click_button "途中保存" }
    assert_text "保存しました。"
    navigate { click_button "入力を再開" }
    assert_text "再開しました。"
    assert_field "Additional name", with: "Extra"
    navigate { click_button "保存して次へ" }
    assert_selector "h1", text: "Part 1"
    fill_in "Name", with: "More"
    navigate { click_button "保存して次へ" }
    assert_current_path "/intake/runs/#{response_run.id}/review"
    assert_selector "h1", text: "回答を確認"
    navigate { click_button "正式に送信する" }
    assert_selector "h1", text: "受付が完了しました"
    assert_text "Extra"
    navigate { click_link "初回の受付・履歴" }
    assert_selector "h1", text: "受付が完了しました"
    assert_text "Original"
    assert_text "回答済み"
    assert_no_text "Extra"
    assert_equal 1, FlowIntakeRequest.where(run_id: @root.id).count
    assert_equal 1, FlowFollowUpAnswer.where(follow_up_request_id: request.id).count
  end

  test "template question can be cancelled and history shows its state" do
    visit "/intake/admin/runs/#{@root.id}"
    navigate { click_link "追加質問を準備" }
    fill_in "質問タイトル", with: "Template question"
    navigate { click_button "質問を準備" }
    assert_selector "h1", text: "Template question"
    navigate { click_button "追加質問を発行" }
    assert_current_path "/intake/admin/runs/#{@root.id}"
    navigate { click_link "第1回 Template question" }
    navigate { click_button "追加質問を取り消す" }
    assert_current_path "/intake/admin/runs/#{@root.id}"
    visit "/intake/runs/#{@root.id}"
    assert_text "取消済み"
    navigate { click_link "質問・回答を開く" }
    assert_text "取り消されたか、有効期限を過ぎています"
  end
  private
    def navigate
      # Do not let an assertion match the old page (for example the edited
      # input value) while its POST/redirect is still replacing the document.
      page.execute_script("window.inquiryNavigationPending = true")
      yield
      Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
        page.evaluate_script("window.inquiryNavigationPending !== true && document.readyState === 'complete'")
      end
    end
end
