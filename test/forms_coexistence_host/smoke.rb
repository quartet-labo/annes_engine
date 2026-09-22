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
    assert_equal 1, PackageRequest.where(run_id: AnnesIntake::Run.last.id).count
    assert_equal 1, AnnesIntake::Response.where(run_id: AnnesIntake::Run.last.id).count
    get "/intake/admin/runs"
    assert_response :forbidden
    get "/intake/admin/runs", headers: {"X-Package-Admin" => "yes"}
    assert_response :success
    assert_select "a", text: AnnesIntake::Run.last.receipt_id
  end
  test "private follow up appends through the shipped engine and leaves the original immutable" do
    inquiry = prepare_inquiry_receipt
    original_inquiry = inquiry.attributes
    original_notifications = inquiry.notification_requests.map(&:attributes)
    form = AnnesIntake::Form.create!(name: "Questions")
    version = form.versions.create!(number: 1, title: "Questions")
    version.fields.create!(key: "name", label: "Name", required: true)
    AnnesIntake::Definitions::PublishVersion.call(version, context: :admin, expected_lock_version: 0)
    flow = AnnesIntake::Flow.create!(key: "follow_package", name: "Follow package")
    fv = flow.versions.create!(number: 1, title: "Questions")
    fv.steps.create!(key: "question", title: "Question", form_version: version)
    AnnesIntake::Flows::Definitions::PublishVersion.call(fv, context: :admin, expected_lock_version: 0)
    AnnesIntake.configuration.adapters[flow.key] = PackageIntakeAdapter.new
    context = "package-customer"
    root = AnnesIntake::Runs::Start.call(flow: flow, context: context)
    complete_package_run(root, "Original")
    original = root.reload.response.attributes
    request = AnnesIntake::FollowUps::Prepare.call(root: root, version: fv, context: context, definition_context: :admin,
      request_key: SecureRandom.uuid, title: "More details", due_at: 1.day.from_now, custom: true)
    assert_empty AnnesIntake::FollowUps::Reader.call(root: root, context: context)
    assert_not_includes AnnesIntake::DefinitionPolicy.new(context: :admin).scope(AnnesIntake::Form.all).pluck(:id), request.definition_version.steps.first.form_version.form_id
    response_run = AnnesIntake::FollowUps::Issue.call(request: request, context: context, definition_context: :admin,
      expected_lock_version: request.lock_version, expected_definition_digest: AnnesIntake::FollowUps::DefinitionDigest.call(request))
    complete_package_run(response_run, "Additional")
    assert request.reload.answered?
    assert_equal original_inquiry, inquiry.reload.attributes
    assert_equal original_notifications, inquiry.notification_requests.map(&:attributes)
    assert_equal "Inquiry original", AnnesInquiry::AnswerReader.new(inquiry)["name"]
    assert_equal 1, AnnesInquiry::Form.count
    assert_equal 1, AnnesInquiry::Submission.count
    assert_equal original, root.reload.response.attributes
    assert_equal 1, PackageRequest.where(run_id: root.id).count
    assert_equal 0, PackageRequest.where(run_id: response_run.id).count
    assert_equal 1, PackageFollowUp.where(run_id: response_run.id).count
    assert_equal "Original", AnnesIntake::Flows::AnswerReader.call(run: root, context: context).dig("question", "name")
    assert_equal "Additional", AnnesIntake::Flows::AnswerReader.call(run: response_run.reload, context: context).dig("question", "name")
    assert_equal request.id, root.notification_requests.find_by!(event_key: "follow_up:#{request.id}:issued").follow_up_request_id
    get "/intake/admin/runs", headers: {"X-Package-Admin" => "yes"}
    assert_select "a", text: root.receipt_id
    assert_select "a", text: response_run.receipt_id, count: 0
  end

  def prepare_inquiry_receipt
    form = AnnesInquiry::Form.create!(key: "isolation", name: "Independent inquiry")
    version = form.versions.create!(number: 1, title: "Inquiry")
    version.fields.create!(key: "name", label: "Name")
    AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    adapter = Object.new
    adapter.define_singleton_method(:deliver) { |request| :sent }
    token = AnnesInquiry::SubmissionToken.issue(version, identity: "inquiry-customer")
    result = AnnesInquiry::SubmissionService.call(form: form, token: token, identity: "inquiry-customer", adapter: adapter, raw_values: {"name" => "Inquiry original"})
    assert result.success?
    result.submission
  end

  def complete_package_run(run, name)
    context = "package-customer"
    step = run.step_runs.first
    token = AnnesIntake::OperationToken.issue(run: run.reload, step: step, action: :save, context: context)
    saved = AnnesIntake::Runs::SaveDraft.call(run: run, step: step, context: context, token: token, raw_values: {"name" => name})
    token = AnnesIntake::OperationToken.issue(run: run.reload, step: step, action: :complete, context: context)
    AnnesIntake::Runs::CompleteStep.call(run: run, step: step, context: context, token: token, expected_revision: saved.revision)
    review = AnnesIntake::Runs::Review.call(run: run.reload, context: context)
    AnnesIntake::Runs::Finalize.call(run: run, context: context, token: review.token)
  end

  def csrf = css_select("meta[name=csrf-token]").first["content"]
  def operation_token = css_select("input[name=token]").first["value"]
end

class FormsCoexistenceSmokeTest < ActionDispatch::IntegrationTest
  test "separate mounts and explicit authorized copy stay independent" do
    form = AnnesInquiry::Form.create!(key: "contact", name: "Contact")
    version = form.versions.create!(number: 1, title: "Contact")
    version.fields.create!(key: "name", label: "Name")
    AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    get "/inquiry/forms/contact"
    assert_response :success
    get "/copy_question/#{version.id}", headers: {"X-Package-Admin" => "yes"}
    assert_response :success
    csrf = css_select("input[name=authenticity_token]").first["value"]
    post "/copy_question/#{version.id}", params: {authenticity_token: csrf}
    assert_response :forbidden
    assert_difference "AnnesIntake::Form.count", 1 do
      post "/copy_question/#{version.id}", params: {authenticity_token: csrf}, headers: {"X-Package-Admin" => "yes"}
    end
    assert_response :created
    assert_includes response.body, "同期されません"
    copied = AnnesIntake::FormVersion.last
    assert copied.draft?
    form.update!(enabled: false)
    assert copied.form.reload.enabled?
    assert copied.draft?
    refute_equal AnnesIntake.configuration, AnnesInquiry.configuration
    assert Rails.application.assets.load_path.find("annes_inquiry/forms.css")
    assert Rails.application.assets.load_path.find("annes_intake/forms.css")
  end
end

class FormsCleanupIsolationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  test "Intake cleanup never deletes Inquiry-owned bytes or notification records" do
    inquiry_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("Inquiry bytes"), filename: "inquiry.txt", content_type: "text/plain", metadata: {"annes_inquiry" => true})
    intake_blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("Intake bytes"), filename: "intake.txt", content_type: "text/plain", metadata: {"annes_intake" => true})
    [inquiry_blob, intake_blob].each { |blob| blob.update_columns(created_at: 2.days.ago) }
    inquiry_notifications = AnnesInquiry::NotificationRequest.order(:id).map(&:attributes)
    AnnesIntake::UnattachedBlobCleanup.call
    assert_equal "Inquiry bytes", inquiry_blob.reload.download
    assert_not ActiveStorage::Blob.exists?(intake_blob.id)
    assert_equal inquiry_notifications, AnnesInquiry::NotificationRequest.order(:id).map(&:attributes)
    assert_not_includes AnnesInquiry::UnattachedBlobCleanup.candidates.map(&:id), intake_blob.id
  ensure
    inquiry_blob&.purge
    intake_blob&.purge if intake_blob && ActiveStorage::Blob.exists?(intake_blob.id)
  end
end
