require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"

class InquiryPackageSmokeTest < Minitest::Test
  def test_rejects_other_databases_and_connection_overrides_before_building
    Dir.mktmpdir("inquiry-package-guard-") do |directory|
      # A regressed guard must never reach real gem installation or DB tasks.
      %w[gem bundle].each do |command|
        path = File.join(directory, command)
        File.write(path, "#!/bin/sh\necho UNEXPECTED_PACKAGE_COMMAND\nexit 99\n")
        File.chmod(0o755, path)
      end
      command_path = "#{directory}:#{ENV.fetch('PATH')}"
      [
        "postgresql:///production",
        "postgresql:///annes_inquiry_package_test?database=production",
        "postgresql:///annes_inquiry_package_test?dbname=production",
        "sqlite3:///annes_inquiry_package_test"
      ].each do |url|
        output, status = Open3.capture2e(
          { "INQUIRY_PACKAGE_DATABASE_URL" => url, "PATH" => command_path, "BUNDLER_ORIG_PATH" => command_path },
          RbConfig.ruby, File.expand_path("../script/check_inquiry_package", __dir__)
        )
        refute status.success?, url
        assert_includes output, "Package smoke requires the dedicated annes_inquiry_package_test database"
        refute_includes output, "UNEXPECTED_PACKAGE_COMMAND"
      end
    end
  end
end
