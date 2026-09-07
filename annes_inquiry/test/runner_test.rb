require "test_helper"
require "open3"
require "tmpdir"

class RunnerTest < ActiveSupport::TestCase
  test "rejects connection overrides before invoking Bundler" do
    [
      "postgres://localhost/annes_inquiry_test?database=anne_mark_development",
      "postgres://localhost/annes_inquiry_test?%64atabase=anne_mark_test",
      "postgres://localhost/anne_mark_test",
      "postgres://localhost/production",
      "sqlite3:///annes_inquiry_test"
    ].each do |url|
      output, status = run_with_fake_bundle(url)
      assert_not status.success?, url
      assert_no_match "BUNDLE_INVOKED", output
      assert_match "INQUIRY_DATABASE_URL must name a separate", output
    end
  end

  test "accepts a separate database with supported connection options" do
    output, status = run_with_fake_bundle("postgres://localhost/annes_inquiry_test?sslmode=require")
    assert status.success?, output
    assert_match "BUNDLE_INVOKED", output
  end

  test "installs the standalone bundle in the runner environment" do
    output, status = run_with_fake_bundle(nil, "--install")
    assert status.success?, output
    assert_match "BUNDLE_INVOKED install", output
    assert_match "/annes_inquiry/Gemfile", output
  end

  private
    def run_with_fake_bundle(url, option = "--prepare")
      Dir.mktmpdir do |directory|
        path = File.join(directory, "bundle")
        File.write(path, "#!/bin/sh\necho BUNDLE_INVOKED $@ $BUNDLE_GEMFILE\n")
        File.chmod(0o755, path)
        runner = File.expand_path("../bin/test", __dir__)
        output, status = Open3.capture2e(
          { "INQUIRY_DATABASE_URL" => url, "PATH" => "#{directory}:#{ENV.fetch('PATH')}" },
          RbConfig.ruby, runner, option
        )
        [ output, status ]
      end
    end
end
