# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"

class PrepareGemReleaseTest < Minitest::Test
  ROOT = Pathname(__dir__).join("..").expand_path
  SCRIPT = ROOT.join("script/prepare_gem_release")

  def test_prepares_release_outputs_for_a_matching_gem_version
    Dir.mktmpdir do |directory|
      notes_file = Pathname(directory).join("notes.md")
      github_output = Pathname(directory).join("github-output.txt")

      stdout, stderr, status = run_script(
        "--gem", "anne_auth",
        "--version", "0.3.5",
        "--notes-file", notes_file.to_s,
        "--github-output", github_output.to_s
      )

      assert status.success?, "#{stdout}\n#{stderr}"
      assert_includes github_output.read, "gem=anne_auth\n"
      assert_includes github_output.read, "path=anne_auth\n"
      assert_includes github_output.read, "gemspec=anne_auth.gemspec\n"
      assert_includes github_output.read, "version=0.3.5\n"
      assert_includes github_output.read, "tag_name=anne_auth-v0.3.5\n"
      assert_includes github_output.read, "notes_file=#{notes_file}\n"

      notes = notes_file.read
      assert_includes notes, "notification stream"
      refute_includes notes, "## 0.3.5"
      refute_includes notes, "## 0.3.3"
    end
  end

  def test_rejects_a_version_that_does_not_match_the_gemspec
    stdout, stderr, status = run_script("--gem", "anne_auth", "--version", "9.9.9")

    refute status.success?, stdout
    assert_includes stderr, "does not match anne_auth gemspec version 0.3.5"
  end

  def test_rejects_an_unknown_gem
    stdout, stderr, status = run_script("--gem", "unknown", "--version", "1.0.0")

    refute status.success?, stdout
    assert_includes stderr, "Unknown gem: unknown"
  end

  def test_rejects_a_missing_changelog_section
    Dir.mktmpdir do |directory|
      root = write_minimal_root(directory, changelog: <<~MARKDOWN)
        # Changelog

        ## Unreleased

        ## 0.3.3

        - Older release.
      MARKDOWN

      stdout, stderr, status = run_script(
        "--root", root.to_s,
        "--gem", "anne_auth",
        "--version", "0.3.5"
      )

      refute status.success?, stdout
      assert_includes stderr, "CHANGELOG section is missing for anne_auth 0.3.5"
    end
  end

  def test_rejects_an_empty_changelog_section
    Dir.mktmpdir do |directory|
      root = write_minimal_root(directory, changelog: <<~MARKDOWN)
        # Changelog

        ## Unreleased

        ## 0.3.5

        ## 0.3.3

        - Older release.
      MARKDOWN

      stdout, stderr, status = run_script(
        "--root", root.to_s,
        "--gem", "anne_auth",
        "--version", "0.3.5"
      )

      refute status.success?, stdout
      assert_includes stderr, "CHANGELOG section is empty for anne_auth 0.3.5"
    end
  end

  private
    def run_script(*arguments)
      Open3.capture3("ruby", SCRIPT.to_s, *arguments, chdir: ROOT.to_s)
    end

    def write_minimal_root(directory, changelog:)
      root = Pathname(directory)
      engine = root.join("anne_auth")
      engine.join("lib/anne_auth").mkpath
      engine.join("lib/anne_auth/version.rb").write(<<~RUBY)
        # frozen_string_literal: true

        module AnneAuth
          VERSION = "0.3.5"
        end
      RUBY
      engine.join("anne_auth.gemspec").write(<<~RUBY)
        # frozen_string_literal: true

        require_relative "lib/anne_auth/version"

        Gem::Specification.new do |spec|
          spec.name = "anne_auth"
          spec.version = AnneAuth::VERSION
          spec.summary = "Fixture"
          spec.authors = [ "Quartet Labo LLC." ]
        end
      RUBY
      engine.join("CHANGELOG.md").write(changelog)
      root
    end
end
