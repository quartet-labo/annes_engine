require "test_helper"
require_relative "../support/flow_test_support"

class FlowAttachmentsTest < ActiveSupport::TestCase
  include FlowTestSupport
  setup do
    build_flow
    @step = @run.step_runs.first
    # Add a file field to a new public form version, then start a newly published flow.
    version = AnnesIntake::Definitions::CloneVersion.call(@step.form_version)
    field = version.fields.create!(key: "document", label: "Document", value_type: "attachment", widget: "file", max_files: 2, max_file_bytes: 10000)
    field.file_types.create!(extension: ".txt", content_type: "text/plain")
    AnnesIntake::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    flow_version = AnnesIntake::Flows::Definitions::CloneVersion.call(@version.reload)
    flow_version.steps.first.update!(form_version: version)
    AnnesIntake::Flows::Definitions::PublishVersion.call(flow_version, expected_lock_version: 0)
    @run = AnnesIntake::Flows::StartRun.call(flow: @flow, context: @context)
    @step = @run.step_runs.first
  end
  teardown do
    AnnesIntake.configuration.adapters.clear
    @files&.each(&:close!)
  end

  test "saved attachments survive resumption and move into immutable receipts" do
    save_upload
    attachment = @step.draft_attachments.sole
    assert attachment.file.attached?
    travel 2.days do
      assert_not_includes AnnesIntake::UnattachedBlobCleanup.candidates.to_a, attachment.file.blob
      AnnesIntake::Flows::ResumeRun.call(run: @run, context: @context)
    end
    @run.step_runs.order(:id).each do |step|
      save(step, {"name" => "Ready"})
      AnnesIntake::Flows::CompleteStep.call(run: @run, step: step, context: @context, token: token(:complete, step))
    end
    validated = []
    @adapter.define_singleton_method(:validate_run) { |run, answers, context| validated << answers.fetch("part_0").fetch("document").map { |file| [file.class.name, file.filename, file.byte_size, file.content_type] }; [] }
    review = AnnesIntake::Runs::Review.call(run: @run, context: @context)
    AnnesIntake::Runs::Finalize.call(run: @run, context: @context, token: review.token)
    assert_equal validated.first, validated.last
    assert_equal [["AnnesIntake::RunPayload::Attachment", "hello.txt", 5, "text/plain"]], validated.first
    answer_attachment = @step.reload.step_response.answers.find_by!(field_id: attachment.field_id).attachments.sole
    assert_equal attachment.file.blob_id, answer_attachment.file.blob_id
    AnnesIntake::Flows::DraftCleanup.call
    assert_equal 1, @step.draft_attachments.count
    assert_equal "hello", answer_attachment.file.download
  end

  test "foreign retained attachment ids and excess counts cannot replace saved files" do
    save_upload
    existing = @step.draft_attachments.sole
    assert_raises(AnnesIntake::Flows::Forbidden) { save(@step, {}, retained_attachments: {"document" => [(existing.id + 1).to_s]}) }
    assert_raises(AnnesIntake::Flows::InvalidInput) { save(@step, {"document" => [upload, upload]}) }
    assert_equal [existing.id], @step.draft_attachments.pluck(:id)
    assert_equal "hello", existing.file.download
  end

  private
    def token(action, step = nil)
      AnnesIntake::Flows::OperationToken.issue(run: @run.reload, action: action, step: step, context: @context)
    end
    def upload
      file = Tempfile.new(["flow", ".txt"])
      file.write("hello"); file.rewind
      (@files ||= []) << file
      ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: "hello.txt", type: "text/plain")
    end
    def save(step, values, **options)
      AnnesIntake::Flows::SaveDraft.call(run: @run, step: step, context: @context, token: token(:save, step), raw_values: values, **options)
    end
    def save_upload
      save(@step, {"name" => "Alice", "document" => [upload]})
    end
end
