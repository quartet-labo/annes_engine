# frozen_string_literal: true

require "minitest/autorun"
require_relative "../script/ci_target_selector"

class CiTargetSelectorTest < Minitest::Test
  def setup
    @selector = CiTargetSelector.new
  end

  def test_selects_each_changed_engine_and_the_dependent_sample_application
    {
      "anne_auth/app/models/anne_auth/account.rb" => %w[anne_auth customer_management reservation_management],
      "anne_admin/lib/anne_admin.rb" => %w[anne_admin customer_management reservation_management],
      "anne_access/test/anne_access_test.rb" => %w[anne_access customer_management reservation_management]
    }.each do |path, expected_names|
      selection = select(path)

      assert_equal expected_names, names(selection)
      refute selection.full_run_reason
    end
  end

  def test_selects_multiple_changed_components
    selection = select(
      "anne_admin/lib/anne_admin.rb",
      "anne_access/test/anne_access_test.rb"
    )

    assert_equal %w[anne_admin anne_access customer_management reservation_management], names(selection)
  end

  def test_selects_only_the_changed_sample_application
    selection = select("examples/customer_management/app/models/customer.rb")

    assert_equal ["customer_management"], names(selection)
  end

  def test_selects_only_the_changed_reservation_management_application
    selection = select("examples/resavation_management/app/models/reservation.rb")

    assert_equal ["reservation_management"], names(selection)
  end

  def test_does_not_select_component_tests_for_documentation_only_changes
    selection = select(
      "README.md",
      "anne_auth/README.md",
      "anne_admin/docs/resource-dsl.md",
      "script/documentation_checker.rb",
      "test/documentation_checker_test.rb",
      "test/public_project_policy_test.rb"
    )

    assert_empty selection.targets
    refute selection.has_tests?
  end

  def test_selects_all_targets_for_ci_workflow_changes
    selection = select(".github/workflows/ci.yml")

    assert_equal all_names, names(selection)
    assert_equal "shared CI path changed: .github/workflows/ci.yml", selection.full_run_reason
  end

  def test_selects_all_targets_for_shared_script_changes
    selection = select("script/select_ci_targets")

    assert_equal all_names, names(selection)
    assert_equal "shared CI path changed: script/select_ci_targets", selection.full_run_reason
  end

  def test_force_all_falls_back_to_every_target
    selection = @selector.select(paths: [], force_all_reason: "unable to compare revisions")

    assert_equal all_names, names(selection)
    assert_equal "unable to compare revisions", selection.full_run_reason
  end

  def test_ignores_paths_that_do_not_map_to_a_test_target
    selection = select(".github/workflows/publish-gems.yml")

    assert_empty selection.targets
  end

  def test_builds_the_dynamic_matrix
    selection = select("examples/customer_management/Gemfile.lock")

    assert_equal(
      {
        include: [
          {
            module: "customer_management",
            path: "examples/customer_management",
            database: "anne_customer_management_test",
            test_command: "bin/rails test"
          }
        ]
      },
      selection.matrix
    )
  end

  def test_builds_the_reservation_management_matrix_entry
    selection = select("examples/resavation_management/Gemfile.lock")

    assert_equal(
      {
        include: [
          {
            module: "reservation_management",
            path: "examples/resavation_management",
            database: "anne_reservation_management_test",
            test_command: "bin/rails test"
          }
        ]
      },
      selection.matrix
    )
  end

  def test_summary_lists_selected_and_skipped_targets
    summary = select("anne_access/lib/anne_access.rb").summary(all_targets: CiTargetSelector::TARGETS)

    assert_includes summary, "- Selected: anne_access, customer_management, reservation_management"
    assert_includes summary, "- Skipped: anne_auth, anne_admin"
    assert_includes summary, "- `anne_access/lib/anne_access.rb`"
  end

  private
    def select(*paths)
      @selector.select(paths:)
    end

    def names(selection)
      selection.targets.map(&:name)
    end

    def all_names
      CiTargetSelector::TARGETS.map(&:name)
    end
end
