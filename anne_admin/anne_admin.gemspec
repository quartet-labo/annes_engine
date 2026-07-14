require_relative "lib/anne_admin/version"

Gem::Specification.new do |spec|
  spec.name = "anne_admin"
  spec.version = AnneAdmin::VERSION
  spec.authors = [ "Anan Mark" ]
  spec.email = [ "development@example.com" ]
  spec.summary = "Reusable admin framework engine for Rails applications."
  spec.description = "Provides configurable resource management screens for Rails applications."
  spec.homepage = "https://github.com/quartet-labo/anne_engine/tree/main/anne_admin"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["source_code_uri"] = "https://github.com/quartet-labo/anne_engine/tree/main/anne_admin"
  spec.metadata["changelog_uri"] = "https://github.com/quartet-labo/anne_engine/blob/main/anne_admin/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/quartet-labo"
  spec.metadata["github_repo"] = "ssh://github.com/quartet-labo/anne_engine"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,docs,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md", "UPGRADING.md"]
  end

  spec.add_dependency "rails", ">= 8.1.0", "< 8.2"

  spec.add_development_dependency "pg", "~> 1.1"
end
