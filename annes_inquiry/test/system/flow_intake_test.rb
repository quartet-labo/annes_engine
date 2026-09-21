require "test_helper"
require "action_dispatch/system_test_case"
require_relative "../support/flow_test_support"

class FlowIntakeSystemTest < ActionDispatch::SystemTestCase
  include FlowTestSupport
  driven_by :selenium, using: :headless_chrome, screen_size: [1280, 1000]
  setup do
    build_flow
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

  test "customer resumes a draft and submits the whole request for administration" do
    visit "/inquiry/flow_runs/#{@run.id}"
    click_link "Part 0"
    fill_in "Name", with: "Alice"
    click_button "途中保存"
    assert_text "保存しました。"
    click_button "再認可して再開"
    assert_text "再開しました。"
    click_link "Part 0"
    assert_field "Name", with: "Alice"
    click_button "保存して次へ"
    assert_current_path "/inquiry/flow_runs/#{@run.id}"
    click_link "Part 1"
    fill_in "Name", with: "Bob"
    click_button "保存して次へ"
    assert_current_path "/inquiry/flow_runs/#{@run.id}"
    click_link "全体の回答を確認"
    assert_text "Alice"
    assert_text "Bob"
    click_button "正式に送信する"
    assert_text "受付が完了しました"
    visit "/inquiry/admin/flows/#{@flow.id}/runs"
    click_link @run.receipt_id
    assert_text "Alice"
    assert_text "Bob"
    assert_text "submitted"
  end

  test "administrator creates publishes and previews a linear definition" do
    visit "/inquiry/admin/flows"
    fill_in "キー", with: "new_intake"
    fill_in "名前", with: "New intake"
    click_button "作成"
    fill_in "ステップキー", with: "contact"
    fill_in "ステップ名", with: "Contact"
    click_button "ステップを追加"
    assert_selector "li", text: "Contact"
    click_link "プレビュー"
    assert_text "Contact"
    assert_no_difference("AnnesInquiry::FlowRun.count") do
      click_button "入力を確認"
      assert_text "Nameを入力してください"
    end
    visit "/inquiry/admin/flows/#{AnnesInquiry::Flow.find_by!(key: 'new_intake').id}"
    click_button "公開する"
    assert_text "published"
  end
end
