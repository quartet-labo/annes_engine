require "test_helper"

class PublicSubmissionsTest < ActionDispatch::IntegrationTest
  setup do
    @form = AnnesInquiry::Form.create!(key: "public_contact", name: "Contact")
    version = @form.versions.create!(number: 1, title: "Contact")
    version.fields.create!(key: "name", label: "Name", required: true)
    AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    AnnesInquiry.configuration.public_endpoints_enabled = true
  end

  teardown { AnnesInquiry.configuration.public_endpoints_enabled = false }

  test "public route is disabled unless explicitly enabled" do
    AnnesInquiry.configuration.public_endpoints_enabled = false
    get "/inquiry/forms/public_contact"
    assert_response :not_found
    post "/inquiry/forms/public_contact", params: { inquiry: { name: "Alice" } }
    assert_response :not_found
  end

  test "invalid input is redisplayed and completion is bound to the sender session" do
    get "/inquiry/forms/public_contact"
    assert_response :success
    token = css_select("input[name=submission_token]").first["value"]
    post "/inquiry/forms/public_contact", params: { submission_token: token, inquiry: { name: "" } }
    assert_response :unprocessable_entity
    post "/inquiry/forms/public_contact", params: { submission_token: token, inquiry: { name: "Alice" } }
    assert_response :see_other
    completion = response.location
    follow_redirect!
    assert_response :success
    other = open_session
    other.get completion
    assert_equal 404, other.response.status
  end

  test "CSRF protection rejects a POST without authenticity token when enabled" do
    AnnesInquiry::PublicSubmissionsController.allow_forgery_protection = true
    get "/inquiry/forms/public_contact"
    token = css_select("input[name=submission_token]").first["value"]
    assert_raises(ActionController::InvalidAuthenticityToken) do
      post "/inquiry/forms/public_contact", params: { submission_token: token, inquiry: { name: "Alice" } }
    end
  ensure
    AnnesInquiry::PublicSubmissionsController.allow_forgery_protection = false
  end
end
