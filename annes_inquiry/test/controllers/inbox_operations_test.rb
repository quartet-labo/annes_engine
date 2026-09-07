require "test_helper"

class InboxOperationsTest < ActionDispatch::IntegrationTest
  setup do
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { true }
    form = AnnesInquiry::Form.create!(key: "operations", name: "Operations")
    version = form.versions.create!(number: 1, title: "Operations")
    @submission = AnnesInquiry::Submission.create!(form_version: version, payload_digest: "a" * 64)
    @pending = @submission.notification_requests.create!(kind: "pending")
    @failed = @submission.notification_requests.create!(kind: "failed", status: "failed")
    @unknown = @submission.notification_requests.create!(kind: "unknown", status: "unknown")
  end
  teardown do
    config = AnnesInquiry.configuration
    config.admin_authenticator = config.admin_authorizer = nil
    config.admin_submission_link = config.admin_notification_action = nil
  end

  test "shows pending failed and unknown with no unconfigured retry actions" do
    get "/inquiry/admin/submissions/#{@submission.id}"
    assert_response :success
    %w[未送信 送信失敗 結果不明].each { |status| assert_includes response.body, status }
    assert_select "form", count: 0
  end

  test "registered host links respect authorization and unknown never gets a resend POST" do
    config = AnnesInquiry.configuration
    config.admin_submission_link = ->(controller, submission) { { label: "案件を開く", path: "/host/projects/1" } }
    config.admin_notification_action = ->(controller, notification) { { label: "再送", path: "/host/retry/#{notification.id}", method: :post } }
    get "/inquiry/admin/submissions/#{@submission.id}"
    assert_select "a[href='/host/projects/1']", text: "案件を開く"
    assert_select "form[action='/host/retry/#{@failed.id}']", count: 1
    assert_select "form[action='/host/retry/#{@unknown.id}']", count: 0
    assert_select "form[action='/host/retry/#{@pending.id}']", count: 0
    config.admin_authorizer = ->(controller, user) { false }
    get "/inquiry/admin/submissions/#{@submission.id}"
    assert_response :forbidden
    assert_not_includes response.body, "/host/projects/1"
  end
end
