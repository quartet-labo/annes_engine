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
    assert_equal 9, Rails.root.join("db/migrate").glob("*.annes_inquiry.rb").size
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

class PackageFlowSmokeTest < ActiveSupport::TestCase
  class Adapter
    def identity(context) = "package-customer"
    def context_key(context) = "package-request"
    def authorize!(**options) = true
    def scope_runs(relation, context:) = relation.where(owner_digest: Digest::SHA256.hexdigest(identity(context)))
    def run_expires_at(context) = 7.days.from_now
    def persist!(run, answers, context)
      FlowIntakeRequest.create!(flow_run_id: run.id, customer_key: identity(context))
    end
    def persist_follow_up!(request, run, answers, context)
      parent = FlowIntakeRequest.find_by!(flow_run_id: request.root_run_id)
      FlowFollowUpAnswer.create!(flow_intake_request: parent, follow_up_request_id: request.id, flow_run_id: run.id)
    end
    def deliver(request) = :sent
  end

  test "shipped flow saves drafts resumes and persists one host request" do
    flow = AnnesInquiry::Flow.create!(key: "package_flow", name: "Package flow")
    version = flow.versions.create!(number: 1, title: "Package flow")
    3.times do |index|
      form = AnnesInquiry::Form.create!(key: "package_step_#{index}", name: "Step")
      fv = form.versions.create!(number: 1, title: "Step")
      fv.fields.create!(key: "name", label: "Name", required: true)
      if index.zero?
        choices = fv.fields.create!(key: "options", label: "Options", value_type: "multiple_choice", widget: "checkbox_group", position: 2)
        %w[a b].each_with_index { |value, i| choices.options.create!(value: value, label: value, position: i) }
        file_field = fv.fields.create!(key: "document", label: "Document", value_type: "attachment", widget: "file", max_files: 1, max_file_bytes: 1000)
        file_field.file_types.create!(extension: ".txt", content_type: "text/plain")
      end
      AnnesInquiry::Definitions::PublishVersion.call(fv, expected_lock_version: 0)
      version.steps.create!(key: "step_#{index}", title: "Step", position: index, form_version: fv)
    end
    first, *optional = version.steps.to_a
    optional.zip(%w[a b]).each do |step, value|
      step.condition_groups.create!.conditions.create!(source_step: first, field: first.form_version.fields.find_by!(key: "options"), operator: "contains", expected_value: value)
      step.value_mappings.create!(source_step: first, source_field: first.form_version.fields.find_by!(key: "name"), target_field: step.form_version.fields.find_by!(key: "name"))
    end
    AnnesInquiry::Flows::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    AnnesInquiry.configuration.flow_adapters[flow.key] = Adapter.new
    run = AnnesInquiry::Flows::StartRun.call(flow: flow, context: nil)
    upload_file = Tempfile.new(["package-flow", ".txt"])
    upload_file.write("retained package attachment"); upload_file.rewind
    run.step_runs.order(:id).each_with_index do |step, index|
      token = AnnesInquiry::Flows::OperationToken.issue(run: run.reload, step: step, context: nil, action: :save)
      AnnesInquiry::Flows::SaveDraft.call(run: run, step: step, context: nil, token: token, raw_values: (index.zero? ? {"name" => "Customer", "options" => %w[a b], "document" => [ActionDispatch::Http::UploadedFile.new(tempfile: upload_file, filename: "document.txt", type: "text/plain")]} : {}))
      AnnesInquiry::Flows::ResumeRun.call(run: run, context: nil)
      token = AnnesInquiry::Flows::OperationToken.issue(run: run.reload, step: step, context: nil, action: :complete)
      AnnesInquiry::Flows::CompleteStep.call(run: run, step: step, context: nil, token: token)
    end
    # Changing selection retains the file and invalidates both downstream steps.
    first_run = run.step_runs.find_by!(flow_step: first)
    [%w[b], %w[a b]].each do |selection|
      save_token = AnnesInquiry::Flows::OperationToken.issue(run: run.reload, step: first_run, context: nil, action: :save)
      AnnesInquiry::Flows::SaveDraft.call(run: run, step: first_run, context: nil, token: save_token, raw_values: {"name" => "Customer", "options" => selection})
      complete_token = AnnesInquiry::Flows::OperationToken.issue(run: run.reload, step: first_run, context: nil, action: :complete)
      AnnesInquiry::Flows::CompleteStep.call(run: run, step: first_run, context: nil, token: complete_token)
      AnnesInquiry::Flows::RouteEvaluator.call(run.reload).drop(1).each do |step|
        token = AnnesInquiry::Flows::OperationToken.issue(run: run.reload, step: step, context: nil, action: :complete)
        AnnesInquiry::Flows::CompleteStep.call(run: run, step: step, context: nil, token: token)
      end
    end
    retained_blob_id = run.step_runs.first.draft_attachments.sole.file.blob_id
    token = AnnesInquiry::Flows::OperationToken.issue(run: run.reload, context: nil, action: :finalize)
    2.times { AnnesInquiry::Flows::FinalizeRun.call(run: run, context: nil, token: token) }
    assert_equal 1, FlowIntakeRequest.where(flow_run_id: run.id).count
    assert_equal 1, run.notification_requests.count
    assert_equal 3, run.step_runs.where.not(submission_id: nil).count
    attachment = AnnesInquiry::AnswerAttachment.where(answer_id: run.step_runs.first.submission.answers.select(:id)).sole
    assert_equal retained_blob_id, attachment.file.blob_id
    assert_equal "retained package attachment", attachment.file.download
    follow_up = AnnesInquiry::Flows::PrepareFollowUp.call(root: run.reload, version: version, context: nil, request_key: SecureRandom.uuid, title: "Package additional questions", due_at: 2.days.from_now, custom: true)
    response = AnnesInquiry::Flows::IssueFollowUp.call(request: follow_up, context: nil, expected_lock_version: follow_up.lock_version, expected_definition_digest: AnnesInquiry::Flows::FollowUpDefinitionDigest.call(follow_up))
    response.step_runs.order(:id).each_with_index do |step, index|
      upload_file.rewind
      values = index.zero? ? {"name" => "Additional", "options" => %w[a b], "document" => [ActionDispatch::Http::UploadedFile.new(tempfile: upload_file, filename: "additional.txt", type: "text/plain")]} : {}
      token = AnnesInquiry::Flows::OperationToken.issue(run: response.reload, step: step, context: nil, action: :save)
      AnnesInquiry::Flows::SaveDraft.call(run: response, step: step, context: nil, token: token, raw_values: values)
      AnnesInquiry::Flows::ResumeRun.call(run: response, context: nil)
      token = AnnesInquiry::Flows::OperationToken.issue(run: response.reload, step: step, context: nil, action: :complete)
      AnnesInquiry::Flows::CompleteStep.call(run: response, step: step, context: nil, token: token)
    end
    token = AnnesInquiry::Flows::OperationToken.issue(run: response.reload, context: nil, action: :finalize)
    2.times { AnnesInquiry::Flows::FinalizeRun.call(run: response, context: nil, token: token) }
    assert_equal 1, FlowIntakeRequest.where(flow_run_id: run.id).count
    assert_equal 1, FlowFollowUpAnswer.where(follow_up_request_id: follow_up.id).count
    assert_equal "answered", follow_up.reload.status
    assert_equal 1, response.notification_requests.where(event_key: "answered").count
    assert_equal retained_blob_id, attachment.reload.file.blob_id
    assert_equal "Customer", AnnesInquiry::Flows::AnswerReader.call(run: run.reload, context: nil).fetch("step_0").fetch("name")
    assert_equal "Additional", AnnesInquiry::Flows::AnswerReader.call(run: response.reload, context: nil).fetch("step_1").fetch("name")
  ensure
    upload_file&.close!
    AnnesInquiry.configuration.flow_adapters.clear
  end
end
