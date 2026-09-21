require "test_helper"

class FlowDefinitionsTest < ActiveSupport::TestCase
  setup do
    form = AnnesInquiry::Form.create!(key: "flow_form", name: "Contact")
    @form_version = form.versions.create!(number: 1, title: "Contact")
    @form_version.fields.create!(key: "name", label: "Name", required: true)
    AnnesInquiry::Definitions::PublishVersion.call(@form_version, expected_lock_version: 0)
    @flow = AnnesInquiry::Flow.create!(key: "intake", name: "Intake")
    @version = @flow.versions.create!(number: 1, title: "Intake")
    @step = @version.steps.create!(key: "contact", title: "Contact", position: 0, form_version: @form_version)
  end

  test "published flow pins immutable steps and supports repeated form versions" do
    @version.steps.create!(key: "other", title: "Other", position: 1, form_version: @form_version)
    publish
    assert @version.reload.published?
    assert_raises(ActiveRecord::RecordNotSaved) { @step.update!(title: "Changed") }
    assert_raises(ActiveRecord::RecordNotSaved) { @version.update!(title: "Changed") }
    assert_raises(ActiveRecord::RecordNotDestroyed) { @step.destroy! }
    assert_raises(ActiveRecord::RecordNotSaved) { @version.steps.create!(key: "late", title: "Late", position: 2, form_version: @form_version) }
    copy = AnnesInquiry::Flows::Definitions::CloneVersion.call(@version)
    assert copy.draft?
    assert_equal %w[contact other], copy.steps.pluck(:key)
    assert_equal [@form_version.id], copy.steps.pluck(:form_version_id).uniq
  end

  test "publishing validates forms and rolls back retirement on failure" do
    publish
    copy = AnnesInquiry::Flows::Definitions::CloneVersion.call(@version)
    @form_version.form.update!(enabled: false)
    assert_raises(AnnesInquiry::Flows::Error) { AnnesInquiry::Flows::Definitions::PublishVersion.call(copy, expected_lock_version: 0) }
    assert @version.reload.published?
    assert copy.reload.draft?
  end

  test "stale editors and empty flows cannot publish" do
    assert_raises(ActiveRecord::StaleObjectError) { AnnesInquiry::Flows::Definitions::DraftEditor.call(@version, expected_lock_version: 9) {} }
    @step.destroy!
    assert_raises(AnnesInquiry::Flows::Error) { publish }
  end

  test "database rejects duplicate step keys and positions" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      AnnesInquiry::FlowStep.transaction(requires_new: true) do
        AnnesInquiry::FlowStep.insert_all!([@step.attributes.except("id").merge("position" => 1)])
      end
    end
    assert_raises(ActiveRecord::RecordNotUnique) do
      AnnesInquiry::FlowStep.transaction(requires_new: true) do
        AnnesInquiry::FlowStep.insert_all!([@step.attributes.except("id").merge("key" => "different")])
      end
    end
  end

  private
    def publish
      AnnesInquiry::Flows::Definitions::PublishVersion.call(@version, expected_lock_version: @version.reload.lock_version)
    end
end
