require "test_helper"

class DefinitionEditorTest < ActionDispatch::IntegrationTest
  setup do
    AnnesInquiry.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesInquiry.configuration.admin_authorizer = ->(controller, user) { true }
    @form = AnnesInquiry::Form.create!(key: "editor", name: "Editor")
    @version = @form.versions.create!(number: 1, title: "Editor")
  end
  teardown do
    AnnesInquiry.configuration.admin_authenticator = nil
    AnnesInquiry.configuration.admin_authorizer = nil
  end

  test "creates all field types with their applicable settings and orders fields" do
    AnnesInquiry::TypeRegistry::WIDGETS.each do |type, widgets|
      post "/inquiry/admin/versions/#{@version.id}/fields", params: { lock_version: @version.reload.lock_version,
        field: { key: type, label: type, value_type: type, widget: widgets.first, position: 10 } }
      assert_response :see_other
    end
    field = @version.fields.find_by!(key: "integer")
    patch "/inquiry/admin/fields/#{field.id}", params: { lock_version: @version.reload.lock_version,
      field: { min_numeric: 1, max_numeric: 100, placeholder: "例：10", position: 0 } }
    assert_response :see_other
    assert_equal "integer", @version.fields.first.key
    assert_equal "例：10", field.reload.placeholder
    get "/inquiry/admin/fields/#{field.id}/edit"
    assert_select "input[name='field[min_numeric]']"
    assert_select "input[name='field[max_file_bytes]']", count: 0
  end

  test "adds edits and removes choices and refuses stale or foreign child updates" do
    field = @version.fields.create!(key: "kind", label: "Kind", value_type: "single_choice", widget: "select")
    post "/inquiry/admin/fields/#{field.id}/options", params: { lock_version: 0, option: { value: "one", label: "One", position: 1 } }
    assert_response :see_other
    option = field.options.first
    patch "/inquiry/admin/fields/#{field.id}/options/#{option.id}", params: { lock_version: 0, option: { label: "Stale" } }
    assert_response :conflict
    assert_equal "One", option.reload.label
    patch "/inquiry/admin/fields/#{field.id}/options/#{option.id}", params: { lock_version: @version.reload.lock_version, option: { label: "Edited", position: 0 } }
    assert_response :see_other
    assert_equal "Edited", option.reload.label
    delete "/inquiry/admin/fields/#{field.id}/options/#{option.id}", params: { lock_version: @version.reload.lock_version }
    assert_response :see_other
    assert_not field.options.exists?
  end

  test "invalid field input is retained and a draft field can be deleted" do
    field = @version.fields.create!(key: "name", label: "Name")
    patch "/inquiry/admin/fields/#{field.id}", params: { lock_version: 0, field: { label: "", placeholder: "Keep me" } }
    assert_response :unprocessable_entity
    assert_select "input[name='field[placeholder]'][value='Keep me']"
    assert_equal "Name", field.reload.label
    delete "/inquiry/admin/fields/#{field.id}", params: { lock_version: @version.reload.lock_version }
    assert_response :see_other
    assert_not @version.fields.exists?
  end
  test "changing type clears incompatible submitted settings and validates attachment rules" do
    field = @version.fields.create!(key: "value", label: "Value", normalizer_key: "trim", max_length: 20)
    patch "/inquiry/admin/fields/#{field.id}", params: { lock_version: 0, field: { value_type: "integer", widget: "number", normalizer_key: "trim", max_length: 20 } }
    assert_response :see_other
    assert_nil field.reload.normalizer_key
    assert_nil field.max_length
    attachment = @version.fields.create!(key: "files", label: "Files", value_type: "attachment", widget: "file")
    post "/inquiry/admin/fields/#{attachment.id}/file_types", params: { lock_version: @version.reload.lock_version, file_type: { extension: ".pdf", content_type: "application/pdf" } }
    assert_response :see_other
    rule = attachment.file_types.first!
    other = @version.fields.create!(key: "other", label: "Other", value_type: "attachment", widget: "file")
    patch "/inquiry/admin/fields/#{other.id}/file_types/#{rule.id}", params: { lock_version: @version.reload.lock_version, file_type: { extension: ".png" } }
    assert_response :not_found
    assert_equal ".pdf", rule.reload.extension
    delete "/inquiry/admin/fields/#{attachment.id}/file_types/#{rule.id}", params: { lock_version: @version.reload.lock_version }
    assert_response :see_other
    assert_not attachment.file_types.exists?
  end

  test "invalid child additions render only one form with the entered values" do
    field = @version.fields.create!(key: "kind", label: "Kind", value_type: "single_choice", widget: "select")
    post "/inquiry/admin/fields/#{field.id}/options", params: { lock_version: 0, option: { value: "", label: "Keep option", position: 0 } }
    assert_response :unprocessable_entity
    assert_select "input[name='option[label]'][value='Keep option']", count: 1
    attachment = @version.fields.create!(key: "files", label: "Files", value_type: "attachment", widget: "file")
    post "/inquiry/admin/fields/#{attachment.id}/file_types", params: { lock_version: 0, file_type: { extension: "wrong", content_type: "application/pdf" } }
    assert_response :unprocessable_entity
    assert_select "input[name='file_type[extension]'][value='wrong']", count: 1
  end

end
