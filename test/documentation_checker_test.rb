# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../script/documentation_checker"

class DocumentationCheckerTest < Minitest::Test
  def test_accepts_closed_fences_and_existing_relative_links
    with_repository do |root|
      write(root, "README.md", <<~MARKDOWN)
        # Example

        [Guide](docs/guide.md)

        ```ruby
        puts "ok"
        ```
      MARKDOWN
      write(root, "docs/guide.md", "# Guide\n")

      assert_empty check(root)
    end
  end

  def test_reports_unclosed_fence
    with_repository do |root|
      write(root, "README.md", "# Example\n\n```ruby\nputs :broken\n")

      errors = check(root)
      assert_equal 1, errors.size
      error = errors.first

      assert_equal Pathname("README.md"), error.path
      assert_equal 3, error.line
      assert_equal "code fence is not closed", error.message
    end
  end

  def test_reports_missing_relative_link
    with_repository do |root|
      write(root, "README.md", "[Missing](docs/missing.md)\n")

      errors = check(root)
      assert_equal 1, errors.size
      error = errors.first

      assert_equal Pathname("README.md"), error.path
      assert_equal 1, error.line
      assert_equal "relative link target does not exist: docs/missing.md", error.message
    end
  end

  def test_ignores_external_anchor_and_code_block_links
    with_repository do |root|
      write(root, "README.md", <<~MARKDOWN)
        [Web](https://example.com)
        [Anchor](#section)

        ```markdown
        [Example only](not-a-real-file.md)
        ```
      MARKDOWN

      assert_empty check(root)
    end
  end

  def test_ignores_internal_planning_documents
    with_repository do |root|
      write(root, "README.md", "# Public\n")
      write(root, ".docs/plan.md", "```ruby\n")

      assert_empty check(root)
    end
  end

  private
    def with_repository
      Dir.mktmpdir { |directory| yield Pathname(directory) }
    end

    def write(root, relative_path, contents)
      path = root.join(relative_path)
      path.dirname.mkpath
      path.write(contents)
    end

    def check(root)
      DocumentationChecker.new(root:).call
    end
end
