# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require "yaml"

class DependencyUpdatesTest < Minitest::Test
  ROOT = Pathname(__dir__).join("..").expand_path
  WORKFLOWS = %w[ci.yml publish-gems.yml].freeze

  def test_dependabot_covers_every_engine_and_example_without_duplicates
    config = YAML.load_file(ROOT.join(".github/dependabot.yml"))
    assert_equal 2, config.fetch("version")

    bundler_updates = config.fetch("updates").select { |update| update.fetch("package-ecosystem") == "bundler" }
    directories = bundler_updates.flat_map { |update| update.fetch("directories") { [update.fetch("directory")] } }
    expected = ROOT.glob("{annes_*,examples/*}/Gemfile").map do |manifest|
      "/#{manifest.dirname.relative_path_from(ROOT)}"
    end

    refute_empty expected
    assert_equal expected.sort, directories.sort
    assert_equal directories.uniq, directories
  end

  def test_dependabot_checks_actions_at_the_repository_root_and_schedules_all_updates
    updates = YAML.load_file(ROOT.join(".github/dependabot.yml")).fetch("updates")
    action_updates = updates.select { |update| update.fetch("package-ecosystem") == "github-actions" }

    assert_equal 1, action_updates.length
    assert_equal "/", action_updates.first.fetch("directory")
    updates.each do |update|
      assert_includes %w[daily weekly monthly quarterly semiannually yearly cron], update.fetch("schedule").fetch("interval")
      refute update.key?("target-branch"), "Updates must follow the default branch"
      assert_operator update.fetch("open-pull-requests-limit", 5), :>, 0
    end
  end

  def test_external_workflow_actions_use_full_commit_shas_with_version_comments
    WORKFLOWS.each do |name|
      path = ROOT.join(".github/workflows", name)
      source = path.read
      steps = YAML.load_file(path).fetch("jobs").values.flat_map { |job| job.fetch("steps", []) }
      actions = steps.filter_map { |step| step["uses"] }.reject { |action| action.start_with?("./", "docker://") }

      refute_empty actions, "#{name} must contain actions to verify"
      actions.each do |action|
        assert_match %r{\A[\w.-]+/[\w./-]+@[0-9a-f]{40}\z}, action, name
        assert_match /^\s*(?:- )?uses: #{Regexp.escape(action)} # v\d+\.\d+\.\d+\s*$/, source, name
      end
    end
  end
end
