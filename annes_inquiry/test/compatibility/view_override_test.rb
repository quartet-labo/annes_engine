require "test_helper"
require_relative "../support/preview_definition"
require "tmpdir"
require "fileutils"

class StandaloneViewOverrideTest < ActionDispatch::IntegrationTest
  include PreviewDefinition
  setup { @version = create_preview_definition }

  test "legacy option IDs and nested field overrides remain available" do
    option = @version.fields.find_by!(key: "multiple_choice_checkbox_group").options.first
    get "/preview/#{@version.id}"
    assert_select "input#inquiry_multiple_choice_checkbox_group_#{option.id}[name='inquiry[multiple_choice_checkbox_group][]']"
    original_paths = PreviewController.view_paths
    Dir.mktmpdir do |directory|
      path = File.join(directory, "annes_inquiry/forms")
      FileUtils.mkdir_p(path)
      File.write(File.join(path, "_text.html.erb"), '<input data-host-override="yes" name="<%= name %>" value="<%= value %>">')
      PreviewController.prepend_view_path(directory)
      get "/preview/#{@version.id}"
      assert_select "input[data-host-override=yes][name='inquiry[text_text]']"
      assert_select "select[multiple]"
    end
  ensure
    PreviewController.view_paths = original_paths if original_paths
  end
end
