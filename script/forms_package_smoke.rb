require "bundler"
require "fileutils"
require "rubygems/package"
require "tmpdir"
require "uri"

module FormsPackageSmoke
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
        [
          ["bundle", "install"],
          ["bundle", "exec", "ruby", "bin/rails", "active_storage:install"],
          ["bundle", "exec", "ruby", "bin/rails", "railties:install:migrations", "FROM=#{(gems - ['annes_form_kit']).join(',')}"],
          ["bundle", "exec", "ruby", "bin/rails", "db:drop", "db:create", "db:migrate"],
          ["bundle", "exec", "ruby", "smoke.rb"]
        ].each do |command|
          abort "Package smoke failed: #{command.join(' ')}" unless system(environment, *command, chdir: host)
        end
      end
    end
  end
end
