require_relative "config/environment"
require "json"

file = Rails.root.join("tmp/legacy.json")
if ARGV.first == "seed"
  abort "Expected the 0.1.0 baseline" unless AnnesInquiry::VERSION == "0.1.0"
  form = AnnesInquiry::Form.create!(key: "upgrade", name: "Upgrade")
  version = form.versions.create!(number: 1, title: "Upgrade")
  version.fields.create!(key: "amount", label: "Amount", value_type: "integer", widget: "number")
  AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
  token = AnnesInquiry::SubmissionToken.issue(version, identity: "existing-customer")
  result = AnnesInquiry::SubmissionService.call(form: form, token: token, identity: "existing-customer", raw_values: {"amount" => "0"})
  abort "Legacy submission failed" unless result.success?
  FileUtils.mkdir_p(file.dirname)
  File.write(file, JSON.generate(token: token, submission_id: result.submission.id, tables: ActiveRecord::Base.connection.tables.sort))
else
  previous = JSON.parse(File.read(file))
  abort "Tables changed during update" unless previous.fetch("tables") == ActiveRecord::Base.connection.tables.sort
  count = AnnesInquiry::Submission.count
  result = AnnesInquiry::SubmissionService.call(form: AnnesInquiry::Form.find_by!(key: "upgrade"), token: previous.fetch("token"), identity: "existing-customer", raw_values: {"amount" => "0"})
  abort "Legacy replay failed" unless result.replayed? && result.submission.id == previous.fetch("submission_id") && AnnesInquiry::Submission.count == count
  abort "Typed legacy answer changed" unless AnnesInquiry::AnswerReader.new(result.submission)["amount"] == 0
  puts "0.1.0 data, token, replay and schema update passed"
end
