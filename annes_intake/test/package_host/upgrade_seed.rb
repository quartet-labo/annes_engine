require_relative "config/environment"
require "tempfile"
abort "Upgrade seed must run against the Plan5 artifact" if AnnesIntake::Run.column_names.include?("follow_up_request_id") || ActiveRecord::Base.connection.table_exists?(:annes_intake_follow_up_requests)
form = AnnesIntake::Form.create!(name: "Plan5 existing")
version = form.versions.create!(number: 1, title: "Existing")
version.fields.create!(key: "name", label: "Name", required: true)
file = version.fields.create!(key: "file", label: "File", value_type: "attachment", widget: "file", max_files: 1, max_file_bytes: 1000)
file.file_types.create!(extension: ".txt", content_type: "text/plain")
AnnesIntake::Definitions::PublishVersion.call(version, expected_lock_version: 0, context: :admin)
flow = AnnesIntake::Flow.create!(key: "upgrade", name: "Existing")
fv = flow.versions.create!(number: 1, title: "Existing")
fv.steps.create!(key: "details", title: "Details", form_version: version)
AnnesIntake::Flows::Definitions::PublishVersion.call(fv, expected_lock_version: 0, context: :admin)
AnnesIntake.configuration.adapters[flow.key] = PackageIntakeAdapter.new
context = "package-customer"
run = AnnesIntake::Runs::Start.call(flow: flow, context: context)
step = run.step_runs.sole
Tempfile.create(["original", ".txt"]) do |io|
  io.write("original attachment"); io.rewind
  upload = ActionDispatch::Http::UploadedFile.new(tempfile: io, filename: "original.txt", type: "text/plain")
  token = AnnesIntake::OperationToken.issue(run: run, step: step, action: :save, context: context)
  saved = AnnesIntake::Runs::SaveDraft.call(run: run, step: step, context: context, token: token, raw_values: {"name" => "Before upgrade", "file" => [upload]})
  token = AnnesIntake::OperationToken.issue(run: run.reload, step: step, action: :complete, context: context)
  AnnesIntake::Runs::CompleteStep.call(run: run, step: step, context: context, token: token, expected_revision: saved.revision)
  review = AnnesIntake::Runs::Review.call(run: run.reload, context: context)
  AnnesIntake::Runs::Finalize.call(run: run, context: context, token: review.token)
end
snapshot = {run: run.reload.attributes, response: run.response.attributes, steps: run.step_runs.map(&:attributes), answers: AnnesIntake::Answer.order(:id).map(&:attributes), attachments: AnnesIntake::AnswerAttachment.order(:id).map(&:attributes)}
File.write("upgrade_snapshot.json", snapshot.to_json)
puts "Plan5 receipt and attachment seeded"
