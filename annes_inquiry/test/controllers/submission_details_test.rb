require "test_helper"

class SubmissionDetailsTest < ActionDispatch::IntegrationTest
  setup do
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { true }
    @form = AnnesInquiry::Form.create!(key: "details", name: "Details")
    @version = @form.versions.create!(number: 1, title: "Original title")
    text = @version.fields.create!(key: "note", label: "Original label")
    integer = @version.fields.create!(key: "count", label: "Count", value_type: "integer", widget: "number")
    boolean = @version.fields.create!(key: "agree", label: "Agree", value_type: "boolean", widget: "checkbox")
    @version.fields.create!(key: "empty", label: "Empty")
    file = @version.fields.create!(key: "file", label: "File", value_type: "attachment", widget: "file", max_files: 1, max_file_bytes: 1024)
    file.file_types.create!(extension: ".txt")
    @submission = AnnesInquiry::Submission.create!(form_version: @version, payload_digest: "a" * 64)
    { text => "<script>alert(1)</script>", integer => 0, boolean => false }.each do |field, value|
      @submission.answers.create!(field: field, form_version: @version, value_type: field.value_type, "#{field.value_type}_value" => value)
    end
    answer = @submission.answers.create!(field: file, form_version: @version, value_type: "attachment")
    @blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("private content"), filename: "private.txt")
    @attachment = answer.attachments.create!(field: file, value_type: "attachment", file: @blob)
    AnnesInquiry::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
  end
  teardown do
    @attachment.destroy!
    @blob.purge
    AnnesInquiry.configuration.admin_authenticator = nil
    AnnesInquiry.configuration.admin_authorizer = nil
  end

  test "shows the original definition with escaped text zero false and unanswered values" do
    draft = AnnesInquiry::Definitions::CloneVersion.call(@version)
    draft.fields.find_by!(key: "note").update!(label: "Changed label")
    AnnesInquiry::Definitions::PublishVersion.call(draft, expected_lock_version: 0)
    get "/inquiry/admin/submissions/#{@submission.id}"
    assert_response :success
    assert_includes response.body, "Original label"
    assert_not_includes response.body, "Changed label"
    assert_select "[data-field-key=count]", text: /0/
    assert_select "[data-field-key=agree]", text: /いいえ/
    assert_select "[data-field-key=empty]", text: /未回答/
    assert_select "script", count: 0
    assert_includes response.body, "&lt;script&gt;"
    assert_select "a[href*='/rails/active_storage']", count: 0
  end

  test "downloads through admin authorization and scopes attachment to the receipt" do
    path = "/inquiry/admin/submissions/#{@submission.id}/attachments/#{@attachment.id}"
    get path
    assert_response :success
    assert_equal "private content", response.body
    assert_includes response.headers["Content-Disposition"], "attachment"
    assert_equal "application/octet-stream", response.media_type
    assert_includes response.headers["Cache-Control"], "no-store"
    other = AnnesInquiry::Submission.create!(form_version: @version, payload_digest: "b" * 64)
    get "/inquiry/admin/submissions/#{other.id}/attachments/#{@attachment.id}"
    assert_response :not_found
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { false }
    get path
    assert_response :forbidden
    get "/inquiry/admin/submissions/#{@submission.id}"
    assert_response :forbidden
  end

  test "streams the authorized download in storage chunks" do
    service = @blob.service
    original = service.method(:download)
    streamed = false
    service.define_singleton_method(:download) do |key, &block|
      raise "Buffered download" unless block
      streamed = true
      block.call("first ")
      block.call("second")
    end
    get "/inquiry/admin/submissions/#{@submission.id}/attachments/#{@attachment.id}"
    assert_response :success
    assert_equal "first second", response.body
    assert streamed
  ensure
    service.singleton_class.remove_method(:download) if original
  end

end
