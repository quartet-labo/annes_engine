require "test_helper"
require "action_dispatch/system_test_case"
require_relative "../support/flow_test_support"

class FlowIntakeSystemTest < ActionDispatch::SystemTestCase
  include FlowTestSupport
  driven_by :selenium, using: :headless_chrome, screen_size: [1280, 1000]
  setup do
    build_flow
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

  test "customer resumes a draft and submits the whole request for administration" do
    visit "/intake/runs/#{@run.id}"
    click_link "Part 0"
    fill_in "Name", with: "Alice"
    click_and_wait "途中保存"
    assert_text "保存しました。"
    click_and_wait "入力を再開"
    assert_text "入力を再開しました。"
    assert_field "Name", with: "Alice"
    click_and_wait "保存して次へ"
    assert_current_path "/intake/runs/#{@run.id}/steps/#{@run.step_runs.order(:id).last.id}"
    fill_in "Name", with: "Bob"
    click_and_wait "保存して次へ"
    assert_current_path "/intake/runs/#{@run.id}/review"
    assert_text "Alice"
    assert_text "Bob"
    click_and_wait "正式に送信する"
    assert_text "受付が完了しました"
    visit "/intake/admin/runs"
    click_link @run.receipt_id
    assert_text "Alice"
    assert_text "Bob"
    assert_text "受付済み"
  end

  test "administrator creates publishes and previews a linear definition" do
    visit "/intake/admin/flows"
    fill_in "名前", with: "New intake"
    click_and_wait "作成"
    fill_in "ステップ名", with: "Contact"
    click_and_wait "ステップを追加"
    assert_selector "li", text: "Contact"
    click_link "プレビュー"
    assert_text "Contact"
    assert_no_difference("AnnesIntake::Run.count") do
      click_and_wait "入力を確認"
      assert_text "Nameを入力してください"
    end
    visit "/intake/admin/flows/#{AnnesIntake::Flow.find_by!(name: 'New intake').id}"
    click_and_wait "公開する"
    assert_text "公開中"
  end
  test "administrator creates a question template without specifying internal keys" do
    visit "/intake/admin/forms"
    click_link "フォームを追加"
    fill_in "管理名", with: "追加の連絡先"
    click_and_wait "フォームを作成"
    assert_selector "h1", text: "追加の連絡先"
    click_link "版1"
    click_link "項目を追加"
    fill_in "ラベル", with: "連絡先名"
    click_and_wait "項目を保存"
    assert_text "連絡先名"
    template = AnnesIntake::Form.find_by!(name: "追加の連絡先")
    visit "/intake/admin/versions/#{template.versions.first.id}"
    click_and_wait "公開する"
    assert_text "公開中"
    click_link "プレビュー"
    assert_field "連絡先名"
  end

  def click_and_wait(label)
    page.execute_script("window.intakeDocumentPending = true")
    click_button label
    Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
      page.evaluate_script("window.intakeDocumentPending !== true && document.readyState === 'complete'")
    end
  end

end
