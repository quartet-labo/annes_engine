require_relative "config/environment"
require "rails/test_help"

class PackageSmokeTest < ActionDispatch::IntegrationTest
  setup do
    AnnesInquiry.configuration.public_endpoints_enabled = true
    @form = AnnesInquiry::Form.create!(key: "package_contact", name: "Package Contact")
    @version = @form.versions.create!(number: 1, title: "Package Contact")
    @version.fields.create!(key: "name", label: "Name", required: true)
    AnnesInquiry::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
  end

  test "built package works after fresh resolution and installed migrations" do
    assert_operator Gem.loaded_specs.fetch("json").version, :<, Gem::Version.new("3.0.0")
    assert_equal Pathname(ENV.fetch("INQUIRY_PACKAGE_PATH")).realpath, AnnesInquiry::Engine.root.realpath
    assert_not AnnesInquiry::Engine.root.join("test").exist?
    assert_equal 5, Rails.root.join("db/migrate").glob("*.annes_inquiry.rb").size
    assert Rails.application.assets.load_path.find("annes_inquiry/forms.css")

    token = AnnesInquiry::SubmissionToken.issue(@version, identity: "package-client")
    result = AnnesInquiry::SubmissionService.call(form: @form, token: token, identity: "package-client", raw_values: { "name" => "Alice" })
    assert_equal 201, result.status
    assert_equal "Alice", AnnesInquiry::AnswerReader.new(result.submission)["name"]

    get "/inquiry/forms/package_contact"
    assert_response :success
    submission_token = css_select("input[name=submission_token]").first["value"]
    authenticity_token = css_select("input[name=authenticity_token]").first["value"]
    assert_difference "AnnesInquiry::Submission.count", 1 do
      post "/inquiry/forms/package_contact", params: { submission_token: submission_token,
        authenticity_token: authenticity_token, inquiry: { name: "Bob" } }
    end
    assert_response :see_other
    follow_redirect!
    assert_response :success

    get "/inquiry/forms/package_contact"
    submission_token = css_select("input[name=submission_token]").first["value"]
    authenticity_token = css_select("input[name=authenticity_token]").first["value"]
    assert_no_difference "AnnesInquiry::Submission.count" do
      post "/inquiry/forms/package_contact", params: { submission_token: submission_token,
        authenticity_token: authenticity_token, inquiry: { name: "Alice\0Bob" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /使用できない文字/
  end
end
