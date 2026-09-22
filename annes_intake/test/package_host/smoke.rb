require_relative "config/environment"
require "rails/test_help"

class IntakePackageSmokeTest < ActionDispatch::IntegrationTest
  test "built gems alone provide a complete intake and scoped management" do
    refute Gem.loaded_specs.key?("annes_inquiry") unless ENV["INQUIRY_PACKAGE_PATH"]
    assert_equal Pathname(ENV.fetch("INTAKE_PACKAGE_PATH")).realpath, AnnesIntake::Engine.root.realpath
    assert Rails.application.assets.load_path.find("annes_intake/forms.css")
    assert Rails.application.assets.load_path.find("annes_intake/forms.js")
    schema = AnnesFormKit::FormSchema.new(title: "質問", fields: [AnnesFormKit::FieldSpec.new(key: "name", label: "お名前", required: true)])
    version = AnnesIntake::Definitions::ImportSchema.call(document: AnnesFormKit::SchemaCodec.dump(schema), context: :admin)
    AnnesIntake::Definitions::PublishVersion.call(version, expected_lock_version: 0, context: :admin)
    flow = AnnesIntake::Flow.create!(key: "package", name: "受付")
    fv = flow.versions.create!(number: 1, title: "受付")
    fv.steps.create!(title: "連絡先", form_version: version)
    AnnesIntake::Flows::Definitions::PublishVersion.call(fv, expected_lock_version: 0, context: :admin)
    get "/intake/flows/package"
    assert_response :success
    post "/intake/flows/package", params: {request_key: css_select("input[name=request_key]").first["value"], authenticity_token: csrf}
    assert_response :see_other
    follow_redirect!
    assert_select "h1", text: "連絡先"
    patch request.path, params: {token: operation_token, authenticity_token: csrf, advance: "1", intake: {name: "Alice"}}
    assert_response :see_other
    follow_redirect!
    assert_select "h1", text: "回答を確認"
    assert_select "p", text: /Alice/
    post "/intake/runs/#{AnnesIntake::Run.last.id}/finalize", params: {token: operation_token, authenticity_token: csrf}
    assert_response :see_other
    follow_redirect!
    assert_select "h1", text: "受付が完了しました"
    assert_equal 1, PackageRequest.count
    assert_equal 1, AnnesIntake::Response.count
    get "/intake/admin/runs"
    assert_response :forbidden
    get "/intake/admin/runs", headers: {"X-Package-Admin" => "yes"}
    assert_response :success
    assert_select "a", text: AnnesIntake::Run.last.receipt_id
  end
  def csrf = css_select("input[name=authenticity_token]").first["value"]
  def operation_token = css_select("input[name=token]").first["value"]
end
