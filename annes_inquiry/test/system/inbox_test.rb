require "test_helper"
require "action_dispatch/system_test_case"

class InboxSystemTest < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 1000 ]
  setup do
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { true }
  end
  teardown do
    AnnesInquiry.configuration.admin_authenticator = nil
    AnnesInquiry.configuration.admin_authorizer = nil
  end

  test "administrator searches and reads the historical answer with its notification state" do
    form = AnnesInquiry::Form.create!(key: "inbox_browser", name: "受付検索テスト")
    version = form.versions.create!(number: 1, title: "受付時のタイトル")
    field = version.fields.create!(key: "name", label: "受付時のお名前")
    submission = AnnesInquiry::Submission.create!(form_version: version, payload_digest: "a" * 64)
    submission.answers.create!(field: field, form_version: version, value_type: "text", text_value: "山田太郎")
    submission.notification_requests.create!(kind: "received", status: "unknown")
    AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    draft = AnnesInquiry::Definitions::CloneVersion.call(version)
    draft.fields.first.update!(label: "変更後の名前")
    AnnesInquiry::Definitions::PublishVersion.call(draft, expected_lock_version: 0)
    visit "/inquiry/admin/submissions"
    select "受付検索テスト", from: "フォーム"
    fill_in "filter_0_key", with: "name"
    fill_in "filter_0_value", with: "山田太郎"
    click_button "検索"
    assert_current_path %r{\A/inquiry/admin/submissions\?}
    click_link submission.receipt_id
    assert_current_path "/inquiry/admin/submissions/#{submission.id}"
    assert_text "受付時のお名前"
    assert_text "山田太郎"
    assert_text "結果不明"
    assert_no_text "変更後の名前"
    save_screenshot(Rails.root.join("tmp/screenshots/inquiry-inbox.png"))
  end
end
