require "test_helper"

class PublishUiTest < ActionDispatch::IntegrationTest
  setup do
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { true }
    @form = AnnesInquiry::Form.create!(key: "publish_ui", name: "Publish")
    @version = @form.versions.create!(number: 1, title: "Publish")
  end
  teardown do
    AnnesInquiry.configuration.admin_authenticator = nil
    AnnesInquiry.configuration.admin_authorizer = nil
  end

  test "invalid definitions cannot publish and preview never saves receipts" do
    post "/inquiry/admin/versions/#{@version.id}/publish", params: { lock_version: 0 }
    assert_response :unprocessable_entity
    assert @version.reload.draft?
    @version.fields.create!(key: "name", label: "Name", required: true)
    assert_no_difference("AnnesInquiry::Submission.count") do
      post "/inquiry/admin/versions/#{@version.id}/preview", params: { inquiry: { name: "" } }
      assert_response :unprocessable_entity
      assert_select "[role=alert]"
      post "/inquiry/admin/versions/#{@version.id}/preview", params: { inquiry: { name: "Alice" } }
      assert_response :success
    end
  end

  test "published versions can only be viewed or duplicated and old edits conflict" do
    field = @version.fields.create!(key: "name", label: "Name")
    post "/inquiry/admin/versions/#{@version.id}/publish", params: { lock_version: 0 }
    assert_response :see_other
    assert @version.reload.published?
    patch "/inquiry/admin/fields/#{field.id}", params: { lock_version: @version.lock_version, field: { label: "Forbidden" } }
    assert_response :unprocessable_entity
    assert_equal "Name", field.reload.label
    get "/inquiry/admin/fields/#{field.id}/edit"
    assert_select "fieldset[disabled]"
    assert_select "input[type=submit]", count: 0
    post "/inquiry/admin/versions/#{@version.id}/duplicate"
    assert_response :see_other
    draft = @form.versions.draft.first!
    patch "/inquiry/admin/versions/#{draft.id}", params: { lock_version: 0, version: { title: "Changed" } }
    assert_response :see_other
    post "/inquiry/admin/versions/#{draft.id}/publish", params: { lock_version: 0 }
    assert_response :conflict
    assert @version.reload.published?
  end

  test "a draft may be deleted and an empty form can start again" do
    delete "/inquiry/admin/versions/#{@version.id}", params: { lock_version: 0 }
    assert_response :see_other
    assert_not @form.versions.exists?
    post "/inquiry/admin/forms/#{@form.id}/draft"
    assert_response :see_other
    assert @form.versions.draft.exists?
  end

  test "admin mutation uses CSRF protection" do
    AnnesInquiry::Admin::VersionsController.allow_forgery_protection = true
    assert_raises(ActionController::InvalidAuthenticityToken) do
      post "/inquiry/admin/versions/#{@version.id}/publish", params: { lock_version: 0 }
    end
  ensure
    AnnesInquiry::Admin::VersionsController.allow_forgery_protection = false
  end
end
