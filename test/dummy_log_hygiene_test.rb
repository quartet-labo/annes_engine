# frozen_string_literal: true

require "minitest/autorun"
require "open3"

class DummyLogHygieneTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  AFFECTED_ENGINES = %w[annes_audit annes_loyalty].freeze

  def test_generated_dummy_logs_are_not_tracked
    paths = git("ls-files", "-z", "--", ":(glob)annes_*/test/dummy/log/**").split("\0")
    generated = paths.reject { |path| path.end_with?("/log/.keep") }

    assert_empty generated, "Generated dummy logs must be untracked: #{generated.join(', ')}"
  end

  def test_repository_rules_ignore_generated_and_rotated_logs
    paths = AFFECTED_ENGINES.flat_map do |engine|
      %w[test.log development.log test.log.1 nested/test.log].map do |name|
        "#{engine}/test/dummy/log/#{name}"
      end
    end

    ignore_rules(paths).each do |path, (source, pattern)|
      assert_equal "#{path.split('/').first}/test/dummy/.gitignore", source, path
      refute pattern.start_with?("!"), "Generated log is explicitly unignored: #{path}"
    end
  end

  def test_log_placeholders_remain_trackable
    paths = AFFECTED_ENGINES.map { |engine| "#{engine}/test/dummy/log/.keep" }

    ignore_rules(paths).each do |path, (_source, pattern)|
      assert pattern.start_with?("!"), "Log placeholder must remain trackable: #{path}"
    end
  end

  private
    def ignore_rules(paths)
      # --no-index checks the policy even if a log has already been force-added.
      output = git(
        "-c", "core.excludesFile=#{File::NULL}",
        "check-ignore", "--no-index", "--verbose", "-z", "--stdin",
        stdin_data: paths.join("\0") + "\0", allowed_statuses: [0, 1]
      )
      rules = output.split("\0").each_slice(4).to_h do |source, _line, pattern, path|
        [path, [source, pattern]]
      end
      assert_equal paths.sort, rules.keys.sort, "Missing repository ignore rules"
      rules
    end

    def git(*arguments, stdin_data: "", allowed_statuses: [0])
      output, error, status = Open3.capture3("git", *arguments, chdir: ROOT, stdin_data:)
      assert_includes allowed_statuses, status.exitstatus, "Git check failed: #{error}"
      output
    end
end
