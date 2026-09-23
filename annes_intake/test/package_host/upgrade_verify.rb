require_relative "config/environment"
require "rails/test_help"
class IntakeUpgradeTest < ActiveSupport::TestCase
  test "Plan5 run response typed answers and stored bytes survive only additive migrations" do
    snapshot = JSON.parse(File.read("upgrade_snapshot.json"))
    run = AnnesIntake::Run.find(snapshot.fetch("run").fetch("id"))
    assert_equal snapshot.fetch("run"), run.attributes.as_json
    assert_equal snapshot.fetch("response"), run.response.attributes.as_json
    assert_equal snapshot.fetch("steps"), run.step_runs.map(&:attributes).as_json
    assert_equal snapshot.fetch("answers"), AnnesIntake::Answer.order(:id).map(&:attributes).as_json
    assert_equal snapshot.fetch("attachments"), AnnesIntake::AnswerAttachment.order(:id).map(&:attributes).as_json
    assert_equal "original attachment", AnnesIntake::AnswerAttachment.sole.file.download
    assert_empty run.follow_up_requests
    AnnesIntake.configuration.adapters[run.flow.key] = PackageIntakeAdapter.new
    assert_equal "Before upgrade", AnnesIntake::Flows::AnswerReader.call(run: run, context: "package-customer").dig("details", "name")
  end
end
