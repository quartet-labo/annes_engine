require_relative "lib/anne_audit/version"

Gem::Specification.new do |spec|
  spec.name = "anne_audit"
  spec.version = AnneAudit::VERSION
  spec.authors = [ "Anan Mark" ]
  spec.email = [ "development@example.com" ]
  spec.summary = "Reusable audit logging engine for Rails applications."
  spec.description = "Provides durable audit event persistence and notification mapping primitives for Rails applications."
  spec.homepage = "https://github.com/quartet-labo/anne_engine/tree/main/anne_audit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["source_code_uri"] = "https://github.com/quartet-labo/anne_engine/tree/main/anne_audit"
  spec.metadata["changelog_uri"] = "https://github.com/quartet-labo/anne_engine/blob/main/anne_audit/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/quartet-labo"
  spec.metadata["github_repo"] = "ssh://github.com/quartet-labo/anne_engine"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,db,docs,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md", "CHANGELOG.md", "UPGRADING.md"]
  end

  spec.add_dependency "rails", ">= 8.1.0", "< 8.2"

  spec.add_development_dependency "pg", "~> 1.1"
end
