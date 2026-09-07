require "test_helper"
require "action_dispatch/system_test_case"

class DefinitionEditorSystemTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 1000 ]
  setup do
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { true }
  end
  teardown do
    AnnesInquiry.configuration.admin_authenticator = nil
    AnnesInquiry.configuration.admin_authorizer = nil
  end

  test "administrator creates a form adds a field and edits its display settings" do
    visit "/inquiry/admin/forms"
    click_link "フォームを追加"
    fill_in "フォームキー", with: "admin_flow"
    fill_in "管理名", with: "管理テスト"
    click_button "フォームを作成"
    click_link "版1"
    click_link "項目を追加"
    fill_in "項目キー", with: "company"
    fill_in "ラベル", with: "会社名"
    fill_in "プレースホルダー", with: "例：株式会社サンプル"
    click_button "項目を保存"
    assert_current_path %r{\A/inquiry/admin/fields/\d+/edit\z}
    assert_selector "h1", text: "会社名の設定"
    assert_field "プレースホルダー", with: "例：株式会社サンプル"
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
    save_screenshot(Rails.root.join("tmp/screenshots/inquiry-editor-mobile.png"))
    click_link "版へ戻る"
    click_link "プレビュー"
    assert_field "会社名", placeholder: "例：株式会社サンプル"
    click_link "版へ戻る"
    click_button "公開する"
    assert_selector "[role=status]", text: "公開しました"
    assert_no_link "項目を追加"
    published_version_path = page.current_path
    click_button "複製して編集"
    assert_no_current_path published_version_path
    assert_selector "h1", text: "版2"
    assert_link "項目を追加"
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
end
