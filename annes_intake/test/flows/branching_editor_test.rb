require "test_helper"
require_relative "../support/flow_test_support"

class FlowBranchingEditorTest < ActionDispatch::IntegrationTest
  include FlowTestSupport
  setup do
    build_flow
    @draft = AnnesIntake::Flows::Definitions::CloneVersion.call(@version)
    @source, @target = @draft.steps.to_a
    form = AnnesIntake::Definitions::CloneVersion.call(@source.form_version)
    @flag = form.fields.create!(key: "flag", label: "Flag", value_type: "boolean", widget: "boolean_radio", position: 1)
    AnnesIntake::Definitions::PublishVersion.call(form, expected_lock_version: 0)
    @source.update!(form_version: form)
    AnnesIntake.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesIntake.configuration.admin_authorizer = ->(controller, user) { true }
  end
  teardown do
    AnnesIntake.configuration.admin_authenticator = nil
    AnnesIntake.configuration.admin_authorizer = nil
    AnnesIntake.configuration.adapters.clear
  end

  test "editor validates ownership and stale locks before persisting conditions and mappings" do
    path = "/intake/admin/flows/#{@flow.id}/versions/#{@draft.id}"
    condition = {source_step_id: @source.id, field_id: @flag.id, operator: "eq", expected_value: "true"}
    patch path, params: {lock_version: @draft.lock_version, rule_step_id: @target.id, condition: condition}
    assert_response :see_other
    assert_equal 1, @target.condition_groups.count
    patch path, params: {lock_version: @draft.lock_version, rule_step_id: @target.id, condition: condition}
    assert_response :conflict
    assert_equal 1, @target.condition_groups.count
    patch path, params: {lock_version: @draft.reload.lock_version, rule_step_id: @target.id, condition: condition.merge(source_step_id: @version.steps.first.id)}
    assert_response :unprocessable_entity
    assert_equal 1, @target.condition_groups.count
    mapping = {source_step_id: @source.id, source_field_id: @source.form_version.fields.find_by!(key: "name").id, target_field_id: @target.form_version.fields.first.id}
    patch path, params: {lock_version: @draft.reload.lock_version, rule_step_id: @target.id, mapping: mapping}
    assert_response :see_other
    assert_equal 1, @target.value_mappings.count
    patch path, params: {lock_version: @draft.reload.lock_version, rule_step_id: @target.id, mapping: mapping}
    assert_response :unprocessable_entity
    assert_equal 1, @target.value_mappings.count
    patch path, params: {lock_version: @draft.reload.lock_version, remove_step_id: @source.id}
    assert_response :unprocessable_entity
    assert_match "参照する条件", response.body
    assert AnnesIntake::Step.exists?(@source.id)
  end
  test "preview waits for valid source input and displays invalid mapped destination" do
    form = AnnesIntake::Definitions::CloneVersion.call(@target.form_version)
    field = form.fields.find_by!(key: "name")
    field.update!(max_length: 2)
    AnnesIntake::Definitions::PublishVersion.call(form, expected_lock_version: 0)
    @target.update!(form_version: form)
    @target.condition_groups.create!.conditions.create!(source_step: @source, field: @flag, operator: "eq", expected_value: "true")
    @target.value_mappings.create!(source_step: @source, source_field: @source.form_version.fields.find_by!(key: "name"), target_field: field)
    path = "/intake/admin/flows/#{@flow.id}/versions/#{@draft.id}/preview"
    post path, params: {answers: {part_0: {flag: "true"}}}
    assert_response :success
    assert_select "h2", text: "Part 1", count: 0
    post path, params: {answers: {part_0: {name: "Long value", flag: "true"}}}
    assert_response :success
    assert_select "h2", text: "Part 1"
    assert_select "[role=alert]", text: /2以下/
  end
end
