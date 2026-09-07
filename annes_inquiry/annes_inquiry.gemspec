require_relative "lib/annes_inquiry/version"

Gem::Specification.new do |spec|
  spec.name = "annes_inquiry"
  spec.version = AnnesInquiry::VERSION
  spec.authors = ["Quartet Labo LLC."]
  spec.summary = "Configurable inquiry forms and typed answers for Rails"
  spec.homepage = "https://github.com/quartet-labo/annes_engine/tree/main/annes_inquiry"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4"
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/quartet-labo/annes_engine/blob/main/annes_inquiry/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/quartet-labo"
  spec.metadata["github_repo"] = "ssh://github.com/quartet-labo/annes_engine"
  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,db,lib}/**/*", "README.md", "CHANGELOG.md", "UPGRADING.md", "MIT-LICENSE"].select { |path| File.file?(path) }
  end
  # Rails 8.1 passes positional JSON options, which JSON 3 no longer accepts.
  spec.add_dependency "json", "< 3"
  spec.add_dependency "rails", "~> 8.1.3", ">= 8.1.3.1"
end
