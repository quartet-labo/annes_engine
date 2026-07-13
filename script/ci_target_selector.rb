# frozen_string_literal: true

class CiTargetSelector
  Target = Data.define(:name, :path, :database, :test_command, :dependency_paths) do
    def matrix_entry
      {
        module: name,
        path:,
        database:,
        test_command:
      }
    end

    def affected_by?(changed_path)
      [path, *dependency_paths].any? do |candidate|
        changed_path == candidate || changed_path.start_with?("#{candidate}/")
      end
    end
  end

  Selection = Data.define(:targets, :changed_paths, :full_run_reason) do
    def has_tests?
      targets.any?
    end

    def matrix
      { include: targets.map(&:matrix_entry) }
    end

    def summary(all_targets:)
      selected_names = targets.map(&:name)
      skipped_names = all_targets.map(&:name) - selected_names

      lines = [
        "## CI test selection",
        "",
        "- Mode: #{selection_mode}",
        "- Selected: #{format_names(selected_names)}",
        "- Skipped: #{format_names(skipped_names)}"
      ]
      lines << "- Reason: #{full_run_reason}" if full_run_reason
      lines.concat(["", "### Changed paths", ""])
      lines.concat(formatted_changed_paths)
      lines.join("\n") << "\n"
    end

    private
      def selection_mode
        return "all targets" if full_run_reason
        return "changed targets" if has_tests?

        "no component tests"
      end

      def format_names(names)
        names.empty? ? "none" : names.join(", ")
      end

      def formatted_changed_paths
        return ["- none"] if changed_paths.empty?

        changed_paths.map { |path| "- `#{path}`" }
      end
  end

  TARGETS = [
    Target.new("anne_auth", "anne_auth", "anne_auth_test", "bundle exec rake test", []),
    Target.new("anne_admin", "anne_admin", "anne_admin_test", "bundle exec rake test", []),
    Target.new("anne_access", "anne_access", "anne_access_test", "bundle exec rake test", []),
    Target.new(
      "customer_management",
      "examples/customer_management",
      "anne_customer_management_test",
      "bin/rails test",
      %w[anne_auth anne_admin anne_access]
    ),
    Target.new(
      "reservation_management",
      "examples/resavation_management",
      "anne_reservation_management_test",
      "bin/rails test",
      %w[anne_auth anne_admin anne_access]
    )
  ].freeze

  DOCUMENTATION_PATHS = %w[
    script/check_docs
    script/documentation_checker.rb
    test/documentation_checker_test.rb
  ].freeze

  SHARED_ROOT_FILES = %w[
    .ruby-version
    .tool-versions
    Gemfile
    Gemfile.lock
    Rakefile
  ].freeze

  def select(paths:, force_all_reason: nil)
    changed_paths = normalize(paths)
    full_run_reason = force_all_reason || full_run_reason(changed_paths)
    targets = if full_run_reason
      TARGETS
    else
      TARGETS.select do |target|
        changed_paths.any? do |path|
          target.affected_by?(path) && !documentation_path?(path)
        end
      end
    end

    Selection.new(targets, changed_paths, full_run_reason)
  end

  private
    def normalize(paths)
      paths.filter_map do |path|
        normalized = path.to_s.strip.sub(%r{\A\./}, "")
        normalized unless normalized.empty?
      end.uniq.sort
    end

    def full_run_reason(paths)
      shared_path = paths.find { |path| shared_path?(path) }
      "shared CI path changed: #{shared_path}" if shared_path
    end

    def shared_path?(path)
      path == ".github/workflows/ci.yml" ||
        path.start_with?(".github/actions/") ||
        SHARED_ROOT_FILES.include?(path) ||
        shared_script_path?(path) ||
        shared_test_path?(path)
    end

    def shared_script_path?(path)
      path.start_with?("script/") && !DOCUMENTATION_PATHS.include?(path)
    end

    def shared_test_path?(path)
      path.start_with?("test/") && !DOCUMENTATION_PATHS.include?(path)
    end

    def documentation_path?(path)
      path == ".docs" ||
        path.start_with?(".docs/") ||
        path.end_with?(".md") ||
        DOCUMENTATION_PATHS.include?(path)
    end
end
