require "bundler"
require "fileutils"
require "rubygems/package"
require "tmpdir"
require "uri"

module FormsPackageSmoke
  # Unreleased Plan5 baseline; pin the reviewed commit, never a moving branch.
  PLAN5_BASELINE = "d61e76d84b6f95a2ec1eed6683c698582b61490d".freeze
  def self.run(combined: false)
    root = File.expand_path("..", __dir__)
    database = combined ? "forms_coexistence_test" : "annes_intake_package_test"
    variable = combined ? "FORMS_COEXISTENCE_DATABASE_URL" : "INTAKE_PACKAGE_DATABASE_URL"
    url = ENV.fetch(variable, "postgresql:///#{database}")
    begin
      uri = URI.parse(url)
      valid = %w[postgres postgresql].include?(uri.scheme) && uri.path == "/#{database}" &&
        (URI.decode_www_form(uri.query.to_s).map(&:first) - %w[sslmode connect_timeout]).empty?
      abort "Package smoke requires the dedicated #{database} database" unless valid
    rescue URI::InvalidURIError, ArgumentError
      abort "Invalid #{variable}"
    end
    Bundler.with_unbundled_env do
      Dir.mktmpdir("intake-package-") do |directory|
        environment = {"DATABASE_URL" => nil, "RAILS_ENV" => "test", "BUNDLE_PATH" => File.join(directory, "bundle"),
          "BUNDLE_APP_CONFIG" => File.join(directory, "bundle_config"), "BUNDLE_FROZEN" => "false", "BUNDLE_DEPLOYMENT" => "false",
          "INTAKE_PACKAGE_DATABASE_URL" => url, "INQUIRY_PACKAGE_PATH" => nil}
        gems = %w[annes_form_kit annes_intake] + (combined ? ["annes_inquiry"] : [])
        gems.each do |name|
          file = File.join(directory, "#{name}.gem")
          abort "Gem build failed" unless system("gem", "build", "#{name}.gemspec", "--output", file, chdir: File.join(root, name))
          package = Gem::Package.new(file)
          path = File.join(directory, name)
          package.extract_files(path)
          File.write(File.join(path, "#{name}.gemspec"), package.spec.to_ruby)
          environment["#{name.delete_prefix('annes_').upcase}_PACKAGE_PATH"] = path
        end
        host = File.join(directory, "host")
        source = combined ? "test/forms_coexistence_host" : "annes_intake/test/package_host"
        FileUtils.cp_r(File.join(root, source), host)
        environment["BUNDLE_GEMFILE"] = File.join(host, "Gemfile")
        unless combined
          baseline = File.join(directory, "plan5_source")
          FileUtils.mkdir_p(baseline)
          archive = File.join(directory, "plan5.tar")
          abort "Baseline unavailable" unless system("git", "archive", "--output", archive, PLAN5_BASELINE, "annes_intake", chdir: root)
          abort "Baseline extraction failed" unless system("tar", "-xf", archive, "-C", baseline)
          file = File.join(directory, "plan5.gem")
          abort "Baseline gem build failed" unless system("gem", "build", "annes_intake.gemspec", "--output", file, chdir: File.join(baseline, "annes_intake"))
          package = Gem::Package.new(file)
          shipped = File.join(directory, "plan5_gem")
          package.extract_files(shipped)
          File.write(File.join(shipped, "annes_intake.gemspec"), package.spec.to_ruby)
          previous = environment.merge("INTAKE_PACKAGE_PATH" => shipped)
          [
            ["bundle", "install"],
            ["bundle", "exec", "ruby", "bin/rails", "active_storage:install"],
            ["bundle", "exec", "ruby", "bin/rails", "railties:install:migrations", "FROM=annes_intake"],
            ["bundle", "exec", "ruby", "bin/rails", "db:drop", "db:create", "db:migrate"],
            ["bundle", "exec", "ruby", "upgrade_seed.rb"]
          ].each do |command|
            abort "Baseline preparation failed" unless system(previous, *command, chdir: host)
          end
        end
        [
          ["bundle", "install"],
          ["bundle", "exec", "ruby", "bin/rails", "active_storage:install"],
          ["bundle", "exec", "ruby", "bin/rails", "railties:install:migrations", "FROM=#{(gems - ['annes_form_kit']).join(',')}"],
          (combined ? ["bundle", "exec", "ruby", "bin/rails", "db:drop", "db:create", "db:migrate"] : ["bundle", "exec", "ruby", "bin/rails", "db:migrate"]),
          *(combined ? [] : [["bundle", "exec", "ruby", "upgrade_verify.rb"]]),
          ["bundle", "exec", "ruby", "smoke.rb"]
        ].each do |command|
          abort "Package smoke failed: #{command.join(' ')}" unless system(environment, *command, chdir: host)
        end
      end
    end
  end
end
