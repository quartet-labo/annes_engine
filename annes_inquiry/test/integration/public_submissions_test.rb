require "test_helper"

class PublicSubmissionsTest < ActionDispatch::IntegrationTest
  setup do
    @form = AnnesInquiry::Form.create!(key: "public_contact", name: "Contact")
    version = @form.versions.create!(number: 1, title: "Contact")
    version.fields.create!(key: "name", label: "Name", required: true)
    AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    AnnesInquiry.configuration.public_endpoints_enabled = true
  end

  teardown do
    AnnesInquiry.configuration.public_endpoints_enabled = false
    AnnesInquiry.configuration.adapters.delete(@form.key)
  end

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

  {
    head: ->(controller) { controller.head :forbidden },
    render: ->(controller) { controller.render plain: "Access denied", status: :forbidden },
    redirect: ->(controller) { controller.redirect_to "/login" }
  }.each do |kind, denial|
    test "prepare_context #{kind} stops submission before persistence" do
      get "/inquiry/forms/public_contact"
      token = css_select("input[name=submission_token]").first["value"]
      persisted = []
      adapter = Object.new
      adapter.define_singleton_method(:prepare_context) { |controller| denial.call(controller) }
      adapter.define_singleton_method(:persist!) { |*args| persisted << args }
      adapter.define_singleton_method(:deliver) { |_| :sent }
      AnnesInquiry.configuration.adapters[@form.key] = adapter

      assert_no_difference [ "AnnesInquiry::Submission.count", "AnnesInquiry::Answer.count",
        "AnnesInquiry::NotificationRequest.count", "ActiveStorage::Blob.count" ] do
        post "/inquiry/forms/public_contact", params: { submission_token: token, inquiry: { name: "Alice" } }
      end
      assert_empty persisted
      if kind == :redirect
        assert_redirected_to "/login"
      else
        assert_response :forbidden
        assert_equal "Access denied", response.body if kind == :render
      end
    end
  end

  test "prepare_context can supply an allowed context to persistence" do
    get "/inquiry/forms/public_contact"
    token = css_select("input[name=submission_token]").first["value"]
    context = { actor: "allowed" }
    persisted_contexts = []
    adapter = Object.new
    adapter.define_singleton_method(:prepare_context) { |_| context }
    adapter.define_singleton_method(:persist!) { |_, _, value| persisted_contexts << value }
    AnnesInquiry.configuration.adapters[@form.key] = adapter

    assert_difference "AnnesInquiry::Submission.count", 1 do
      post "/inquiry/forms/public_contact", params: { submission_token: token, inquiry: { name: "Alice" } }
    end
    assert_response :see_other
    assert_equal [ context ], persisted_contexts
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
