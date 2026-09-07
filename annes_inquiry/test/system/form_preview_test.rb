require "test_helper"
require "action_dispatch/system_test_case"
require_relative "../support/preview_definition"

class FormPreviewTest < ActionDispatch::SystemTestCase
  include PreviewDefinition
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 1000 ]

  test "all widgets remain usable on a narrow screen" do
    version = create_preview_definition
    visit "/preview/#{version.id}"
    assert_text "お問い合わせプレビュー"
    fill_in "text text", with: "テスト入力"
    select "選択肢１", from: "single_choice select"
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width: 390, height: 844, deviceScaleFactor: 1, mobile: true)
    assert_selector "input[type=file]", visible: true
    assert_operator page.evaluate_script("document.documentElement.scrollWidth"), :<=, 390
    save_screenshot(Rails.root.join("tmp/screenshots/inquiry-preview-mobile.png"))
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end
  test "invalid dates remain visible after server validation" do
    version = create_preview_definition
    visit "/preview/#{version.id}"
    page.execute_script(<<~JS)
      document.querySelector('form').noValidate = true;
      const field = document.querySelector('#inquiry_date_date');
      field.type = 'text';
      field.value = '2026-02-30';
    JS
    click_button "送信"
    assert_selector "[role=alert]", text: "の形式または桁数が正しくありません"
    assert_field "date date", with: "2026-02-30", type: "text"
  end

end
