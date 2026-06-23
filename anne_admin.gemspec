require_relative "lib/anne_admin/version"

Gem::Specification.new do |spec|
  spec.name = "anne_admin"
  spec.version = AnneAdmin::VERSION
  spec.authors = [ "Anan Mark" ]
  spec.email = [ "development@example.com" ]
  spec.summary = "Reusable admin framework engine for Rails applications."
  spec.description = "Provides configurable resource management screens for Rails applications."
  spec.homepage = "https://example.com/anne_admin"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to private gem server"
  spec.metadata["source_code_uri"] = "https://example.com/anne_admin"
  spec.metadata["changelog_uri"] = "https://example.com/anne_admin/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,lib}/**/*", "Rakefile", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "rails", ">= 8.1.0", "< 8.2"
end
