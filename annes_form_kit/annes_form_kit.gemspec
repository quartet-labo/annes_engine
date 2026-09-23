require_relative "lib/annes_form_kit/version"

Gem::Specification.new do |spec|
  spec.name = "annes_form_kit"
  spec.version = AnnesFormKit::VERSION
  spec.authors = ["Quartet Labo LLC."]
  spec.summary = "Database-free form schemas, validation and rendering for Rails"
  spec.homepage = "https://github.com/quartet-labo/annes_engine/tree/main/annes_form_kit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/quartet-labo/annes_engine/blob/main/annes_form_kit/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/quartet-labo"
  spec.metadata["github_repo"] = "ssh://github.com/quartet-labo/annes_engine"
  spec.files = Dir.chdir(__dir__) do
    Dir["{lib,views}/**/*", "README.md", "CHANGELOG.md", "UPGRADING.md", "MIT-LICENSE"].select { |path| File.file?(path) }
  end
  spec.add_dependency "activesupport", "~> 8.1.3", ">= 8.1.3.1"
  spec.add_dependency "activemodel", "~> 8.1.3", ">= 8.1.3.1"
  spec.add_dependency "actionview", "~> 8.1.3", ">= 8.1.3.1"
  spec.add_dependency "marcel", "~> 1.0"
  spec.add_dependency "json", "< 3"
end
