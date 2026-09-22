require "test_helper"
require "action_dispatch/system_test_case"
require_relative "../support/flow_test_support"

class FlowBranchingSystemTest < ActionDispatch::SystemTestCase
  include FlowTestSupport
  driven_by :selenium, using: :headless_chrome, screen_size: [1280, 1000]
  setup do
    build_flow
    draft = AnnesIntake::Flows::Definitions::CloneVersion.call(@version)
    source, target = draft.steps.to_a
    form = AnnesIntake::Definitions::CloneVersion.call(source.form_version)
    options = form.fields.create!(key: "options", label: "Options", value_type: "multiple_choice", widget: "checkbox_group", position: 1)
    %w[a b].each_with_index { |value, i| options.options.create!(value: value, label: "Option #{value.upcase}", position: i) }
    AnnesIntake::Definitions::PublishVersion.call(form, expected_lock_version: 0)
    source.update!(form_version: form)
    other = draft.steps.create!(key: "other", title: "Other", position: 2, form_version: target.form_version)
    [target, other].zip(%w[a b]).each do |step, value|
      step.condition_groups.create!.conditions.create!(source_step: source, field: options, operator: "contains", expected_value: value)
      step.value_mappings.create!(source_step: source, source_field: form.fields.find_by!(key: "name"), target_field: step.form_version.fields.find_by!(key: "name"))
    end
    AnnesIntake::Flows::Definitions::PublishVersion.call(draft, expected_lock_version: 0)
    @version = draft
    AnnesIntake.configuration.endpoints_enabled = true
    AnnesIntake.configuration.admin_authenticator = ->(controller) { :admin }
    AnnesIntake.configuration.admin_authorizer = ->(controller, user) { true }
  end
  teardown do
    AnnesIntake.configuration.endpoints_enabled = false
    AnnesIntake.configuration.adapters.clear
    AnnesIntake.configuration.admin_authenticator = nil
    AnnesIntake.configuration.admin_authorizer = nil
  end

  [[], ["A"], ["B"], %w[A B]].each do |selection|
    test "participant completes selected options #{selection.join.presence || 'none'}" do
      run = AnnesIntake::Flows::StartRun.call(flow: @flow, context: @context)
      visit "/intake/runs/#{run.id}"
      click_link "Part 0"
      fill_in "Name", with: "Customer"
      selection.each { |option| check "Option #{option}" }
      click_and_wait "保存して次へ"
      {"A" => "Part 1", "B" => "Other"}.each do |option, title|
        if selection.include?(option)
          assert_selector "h1", text: title
          assert_text "Customer"
          assert_no_field "Name"
          click_and_wait "保存して次へ"
            else
          assert_no_link title
        end
      end
      assert_current_path "/intake/runs/#{run.id}/review"
      assert_text "Customer"
      click_and_wait "正式に送信する"
      assert_selector "h1", text: "受付が完了しました"
      assert_equal selection.size + 1, run.step_runs.where.not(step_response_id: nil).count
    end
  end

  test "preview recalculates independent branches and read only values" do
    visit "/intake/admin/flows/#{@flow.id}/versions/#{@version.id}/preview"
    assert_no_selector "h2", text: "Part 1"
    fill_in "Name", with: "Preview"
    check "Option A"
    check "Option B"
    submit_preview
    assert_selector "h2", text: "Part 1"
    assert_selector "h2", text: "Other"
    assert_text "Name（引継ぎ）: Preview", count: 2
    uncheck "Option A"
    submit_preview
    assert_no_selector "h2", text: "Part 1"
    assert_selector "h2", text: "Other"
  end

  private
    def submit_preview
      # POST renders the same URL. Wait for the old document to be replaced
      # before Capybara reads nodes that Chrome may already have detached.
      page.execute_script("window.intakePreviewPending = true")
      click_and_wait "入力を確認"
      Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
        page.evaluate_script("window.intakePreviewPending !== true && document.readyState === 'complete'")
      end
    end
  def click_and_wait(label)
    page.execute_script("window.intakeDocumentPending = true")
    click_button label
    Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
      page.evaluate_script("window.intakeDocumentPending !== true && document.readyState === 'complete'")
    end
  end

end
