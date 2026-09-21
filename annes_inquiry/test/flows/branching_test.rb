require "test_helper"
require_relative "../support/flow_test_support"

class FlowBranchingTest < ActiveSupport::TestCase
  include FlowTestSupport

  setup do
    build_flow
    @draft = AnnesInquiry::Flows::Definitions::CloneVersion.call(@version)
    @source, @target = @draft.steps.to_a
    form = AnnesInquiry::Definitions::CloneVersion.call(@source.form_version)
    @choices = form.fields.create!(key: "options", label: "Options", value_type: "multiple_choice", widget: "checkbox_group", position: 1)
    %w[a b].each_with_index { |value, i| @choices.options.create!(value: value, label: value.upcase, position: i) }
    AnnesInquiry::Definitions::PublishVersion.call(form, expected_lock_version: 0)
    @source.update!(form_version: form)
    @target.condition_groups.create!.conditions.create!(source_step: @source, field: @choices, operator: "contains", expected_value: "a")
    @target.value_mappings.create!(source_step: @source, source_field: form.fields.find_by!(key: "name"), target_field: @target.form_version.fields.find_by!(key: "name"))
    AnnesInquiry::Flows::Definitions::PublishVersion.call(@draft, expected_lock_version: 0)
    @run = AnnesInquiry::Flows::StartRun.call(flow: @flow, context: @context, request_key: SecureRandom.uuid)
    @first, @second = @run.step_runs.order(:id).to_a
  end

  teardown { AnnesInquiry.configuration.flow_adapters.clear }

  test "conditions use completed active answers and mapped values are read only" do
    assert_equal [@first.id], path.map(&:id)
    save(@first, {"name" => "Alice", "options" => ["a", "b"]})
    assert_equal [@first.id], path.map(&:id)
    complete(@first)
    assert_equal [@first.id, @second.id], path.map(&:id)
    assert_raises(AnnesInquiry::Flows::Conflict) { save(@second, {"name" => "Tampered"}) }
    save(@second, {})
    complete(@second)
    finalize
    assert_equal "Alice", @adapter.persisted.last.last.fetch("part_1").fetch("name")
  end

  test "removed paths keep drafts exclude submissions and require confirmation when restored" do
    save(@first, {"name" => "First", "options" => ["a"]}); complete(@first)
    save(@second, {}); complete(@second)
    stale = token(:finalize)
    save(@first, {"name" => "Changed", "options" => ["b"]}); complete(@first)
    assert @second.reload.inactive?
    assert_raises(AnnesInquiry::Flows::Conflict) { AnnesInquiry::Flows::FinalizeRun.call(run: @run, context: @context, token: stale) }
    save(@first, {"name" => "Restored", "options" => ["a"]}); complete(@first)
    assert @second.reload.draft?
    assert_equal "Restored", AnnesInquiry::Flows::RouteEvaluator.raw_values(@second).fetch("name")
    save(@first, {"name" => "Final", "options" => []}); complete(@first)
    finalize
    assert_equal ["part_0"], @adapter.persisted.last.last.keys
    assert_nil @second.reload.submission_id
  end

  test "cloning remaps conditions and mappings and published rules cannot be edited" do
    group = @target.condition_groups.first
    assert_raises(ActiveRecord::RecordNotDestroyed) { group.destroy! }
    clone = AnnesInquiry::Flows::Definitions::CloneVersion.call(@draft)
    source, target = clone.steps.to_a
    assert_equal source.id, target.condition_groups.first.conditions.first.source_step_id
    assert_equal source.id, target.value_mappings.first.source_step_id
    assert_raises(AnnesInquiry::Flows::Error) do
      target.condition_groups.first.conditions.first.update!(source_step: target)
      AnnesInquiry::Flows::Definitions::Validator.call(clone)
    end
  end

  test "independent optional steps allow none either and both selections" do
    clone = AnnesInquiry::Flows::Definitions::CloneVersion.call(@draft)
    source, target = clone.steps.to_a
    other = clone.steps.create!(key: "other", title: "Other", position: 2, form_version: target.form_version)
    other.condition_groups.create!.conditions.create!(source_step: source, field: @choices, operator: "contains", expected_value: "b")
    AnnesInquiry::Flows::Definitions::PublishVersion.call(clone, expected_lock_version: 0)
    {[] => ["part_0"], ["a"] => %w[part_0 part_1], ["b"] => %w[part_0 other], %w[a b] => %w[part_0 part_1 other]}.each do |selection, keys|
      @run = AnnesInquiry::Flows::StartRun.call(flow: @flow, context: @context)
      first = @run.step_runs.find_by!(flow_step: source)
      save(first, {"name" => "Customer", "options" => selection}); complete(first)
      assert_equal keys, path.map(&:key)
    end
  end

  test "boolean false is a value while missing and inactive sources do not match" do
    clone = AnnesInquiry::Flows::Definitions::CloneVersion.call(@draft)
    source, target = clone.steps.to_a
    form = AnnesInquiry::Definitions::CloneVersion.call(source.form_version)
    flag = form.fields.create!(key: "flag", label: "Flag", value_type: "boolean", widget: "boolean_radio", position: 2)
    AnnesInquiry::Definitions::PublishVersion.call(form, expected_lock_version: 0)
    source.update!(form_version: form)
    target.condition_groups.destroy_all
    target.value_mappings.destroy_all
    group = target.condition_groups.create!
    group.conditions.create!(source_step: source, field: flag, operator: "eq", expected_value: "false")
    group.conditions.create!(source_step: source, field: form.fields.find_by!(key: "options"), operator: "contains", expected_value: "a")
    {nil => false, "0" => true, "false" => true, "true" => false}.each do |raw, active|
      result = AnnesInquiry::Flows::RouteEvaluator.preview(clone, {"part_0" => {"name" => "A", "flag" => raw, "options" => ["a"]}})
      assert_equal active, result.steps.include?(target)
    end
    result = AnnesInquiry::Flows::RouteEvaluator.preview(clone, {"part_0" => {"name" => "A", "flag" => "false", "options" => []}})
    assert_not_includes result.steps, target
    # Adding an alternative group permits either a or b.
    target.condition_groups.create!.conditions.create!(source_step: source, field: form.fields.find_by!(key: "options"), operator: "contains", expected_value: "b")
    assert_includes AnnesInquiry::Flows::RouteEvaluator.preview(clone, {"part_0" => {"name" => "A", "options" => ["b"]}}).steps, target
  end

  test "publishing rejects foreign fields unknown options unsupported types and incompatible mappings" do
    clone = AnnesInquiry::Flows::Definitions::CloneVersion.call(@draft)
    source, target = clone.steps.to_a
    condition = target.condition_groups.first.conditions.first
    [{expected_value: "unknown"}, {operator: "eq"}, {field: target.form_version.fields.first}, {source_step: target}].each do |attributes|
      original = condition.attributes
      condition.update!(attributes)
      assert_raises(AnnesInquiry::Flows::Error) { AnnesInquiry::Flows::Definitions::Validator.rules!(target) }
      condition.update!(original.except("id", "created_at", "updated_at"))
    end
    mapping = target.value_mappings.first
    mapping.update!(source_field: @choices)
    assert_raises(AnnesInquiry::Flows::Error) { AnnesInquiry::Flows::Definitions::Validator.rules!(target) }
    assert_raises(ActiveRecord::RecordInvalid) { target.value_mappings.create!(source_step: source, source_field: source.form_version.fields.first, target_field: mapping.target_field) }
  end

  test "inactive branch retains its text and file without copying them to the receipt" do
    clone = AnnesInquiry::Flows::Definitions::CloneVersion.call(@draft)
    source, target = clone.steps.to_a
    form = AnnesInquiry::Definitions::CloneVersion.call(target.form_version)
    form.fields.create!(key: "note", label: "Note", position: 1)
    file = form.fields.create!(key: "document", label: "Document", value_type: "attachment", widget: "file", position: 2, max_files: 1, max_file_bytes: 1000)
    file.file_types.create!(extension: ".txt", content_type: "text/plain")
    AnnesInquiry::Definitions::PublishVersion.call(form, expected_lock_version: 0)
    target.update!(form_version: form)
    target.value_mappings.first.update!(target_field: form.fields.find_by!(key: "name"))
    AnnesInquiry::Flows::Definitions::PublishVersion.call(clone, expected_lock_version: 0)
    @run = AnnesInquiry::Flows::StartRun.call(flow: @flow, context: @context)
    first, second = @run.step_runs.order(:id).to_a
    upload = Tempfile.new(["branch", ".txt"])
    upload.write("Retained branch file"); upload.rewind
    save(first, {"name" => "Alice", "options" => ["a"]}); complete(first)
    save(second, {"note" => "Retained text", "document" => [ActionDispatch::Http::UploadedFile.new(tempfile: upload, filename: "branch.txt", type: "text/plain")]}); complete(second)
    blob = second.draft_attachments.sole.file.blob
    save(first, {"name" => "Alice", "options" => []}); complete(first)
    assert second.reload.inactive?
    assert_equal "Retained text", AnnesInquiry::Flows::DraftReader.call(second).fetch("note")
    finalize
    assert_nil second.reload.submission_id
    assert_equal ["part_0"], @adapter.persisted.last.last.keys
    assert_equal "Retained branch file", blob.download
    assert_equal 0, AnnesInquiry::AnswerAttachment.where(field_id: file.id).count
  ensure
    upload&.close!
  end

  private
    def path = AnnesInquiry::Flows::RouteEvaluator.call(@run.reload)
    def token(action, step = nil) = AnnesInquiry::Flows::OperationToken.issue(run: @run.reload, step: step, action: action, context: @context)
    def save(step, raw)
      AnnesInquiry::Flows::SaveDraft.call(run: @run, step: step, context: @context, token: token(:save, step), raw_values: raw)
    end
    def complete(step)
      AnnesInquiry::Flows::CompleteStep.call(run: @run, step: step, context: @context, token: token(:complete, step))
    end
    def finalize = AnnesInquiry::Flows::FinalizeRun.call(run: @run, context: @context, token: token(:finalize))
end
