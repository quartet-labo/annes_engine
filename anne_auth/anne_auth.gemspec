require_relative "lib/anne_auth/version"

Gem::Specification.new do |spec|
  spec.name = "anne_auth"
  spec.version = AnneAuth::VERSION
  spec.authors = [ "Anan Mark" ]
  spec.email = [ "development@example.com" ]
  spec.summary = "Reusable authentication engine for Rails applications."
  spec.description = "Provides account, session, verification, password reset, and OAuth authentication primitives."
  spec.homepage = "https://github.com/quartet-labo/anne_engine/tree/main/anne_auth"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["source_code_uri"] = "https://github.com/quartet-labo/anne_engine/tree/main/anne_auth"
  spec.metadata["changelog_uri"] = "https://github.com/quartet-labo/anne_engine/blob/main/anne_auth/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/quartet-labo"
  spec.metadata["github_repo"] = "ssh://github.com/quartet-labo/anne_engine"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.1.0", "< 8.2"
  spec.add_dependency "bcrypt", "~> 3.1.7"
  spec.add_dependency "omniauth", "~> 2.1"
  spec.add_dependency "omniauth-google-oauth2", "~> 1.2"

  spec.add_development_dependency "pg", "~> 1.1"
end
