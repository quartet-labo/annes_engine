# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "pathname"
require "tmpdir"
require "rubygems/package"

class MitLicenseComplianceTest < Minitest::Test
  ROOT = Pathname(__dir__).join("..").expand_path
  CHECKER = ROOT.join("script/check_gem_license")
  ENGINE_GEMSPECS = {
    "annes_auth" => "annes_auth.gemspec",
    "annes_access" => "annes_access.gemspec",
    "annes_admin" => "annes_admin.gemspec"
  }.freeze
  EXPECTED_LICENSE = <<~LICENSE
    Copyright (c) 2026 Quartet Labo LLC.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
  LICENSE

  def test_repository_and_engine_license_files_match_the_approved_text
    paths = [ ROOT.join("MIT-LICENSE") ] + ENGINE_GEMSPECS.keys.map do |engine|
      ROOT.join(engine, "MIT-LICENSE")
    end

    paths.each do |path|
      assert path.file?, "Missing MIT license: #{path.relative_path_from(ROOT)}"
      assert_equal EXPECTED_LICENSE, path.read, "Unexpected MIT license text in #{path.relative_path_from(ROOT)}"
    end
  end

  def test_each_gemspec_declares_mit_and_packages_the_license
    ENGINE_GEMSPECS.each do |engine, gemspec_name|
      gemspec = Gem::Specification.load(ROOT.join(engine, gemspec_name).to_s)

      refute_nil gemspec, "Could not load #{engine}/#{gemspec_name}"
      assert_equal [ "MIT" ], gemspec.licenses
      assert_includes gemspec.files, "MIT-LICENSE"
    end
  end

  def test_built_engine_gems_pass_the_package_checker
    ENGINE_GEMSPECS.each do |engine, gemspec_name|
      Dir.mktmpdir do |directory|
        output = Pathname(directory).join("#{engine}.gem")
        stdout, stderr, status = Open3.capture3(
          "gem", "build", gemspec_name, "--output", output.to_s,
          chdir: ROOT.join(engine).to_s
        )
        assert status.success?, "Could not build #{engine}:\n#{stdout}\n#{stderr}"

        stdout, stderr, status = Open3.capture3("ruby", CHECKER.to_s, output.to_s, chdir: ROOT.to_s)
        assert status.success?, "License check failed for #{engine}:\n#{stdout}\n#{stderr}"
      end
    end
  end

  def test_package_checker_rejects_non_mit_metadata
    gem_path = build_fixture_gem(license: "Apache-2.0", license_text: EXPECTED_LICENSE)

    _stdout, stderr, status = Open3.capture3("ruby", CHECKER.to_s, gem_path.to_s, chdir: ROOT.to_s)

    refute status.success?
    assert_includes stderr, "license metadata must be MIT"
  ensure
    FileUtils.remove_entry(gem_path.dirname) if gem_path
  end

  def test_package_checker_rejects_a_missing_license_file
    gem_path = build_fixture_gem(license: "MIT", license_text: nil)

    _stdout, stderr, status = Open3.capture3("ruby", CHECKER.to_s, gem_path.to_s, chdir: ROOT.to_s)

    refute status.success?
    assert_includes stderr, "MIT-LICENSE is missing"
  ensure
    FileUtils.remove_entry(gem_path.dirname) if gem_path
  end

  def test_package_checker_rejects_modified_license_text
    gem_path = build_fixture_gem(license: "MIT", license_text: "not the approved license\n")

    _stdout, stderr, status = Open3.capture3("ruby", CHECKER.to_s, gem_path.to_s, chdir: ROOT.to_s)

    refute status.success?
    assert_includes stderr, "MIT-LICENSE does not match"
  ensure
    FileUtils.remove_entry(gem_path.dirname) if gem_path
  end

  private
    def build_fixture_gem(license:, license_text:)
      directory = Pathname(Dir.mktmpdir)
      directory.join("lib").mkpath
      directory.join("lib/fixture.rb").write("# frozen_string_literal: true\n")
      directory.join("MIT-LICENSE").write(license_text) if license_text

      spec = Gem::Specification.new do |gem|
        gem.name = "mit-license-fixture"
        gem.version = "1.0.0"
        gem.summary = "Fixture gem for license compliance tests"
        gem.authors = [ "Quartet Labo LLC." ]
        gem.homepage = "https://github.com/quartet-labo/anne_engine"
        gem.required_ruby_version = ">= 3.4.0"
        gem.files = [ "lib/fixture.rb" ]
        gem.files << "MIT-LICENSE" if license_text
        gem.license = license
      end

      gem_path = directory.join("fixture.gem")
      Dir.chdir(directory) { Gem::Package.build(spec, false, false, gem_path.to_s) }
      gem_path
    end
end
