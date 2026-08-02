require_relative "test_helper"

class AnneAudit::PackageBoundaryTest < AnneAudit::TestCase
  HOST_DOMAIN_REFERENCES = [
    /\bCustomer\b/,
    /\bProject\b/,
    /\bQuotation\b/,
    /\bQuoteRequest\b/,
    /\bCustomerAccount(?:Membership|Project)?\b/,
    /\bCustomerSession\b/,
    /\bCustomerAccounts::/,
    /\bProjectToken\b/,
    /\bMailDelivery\b/
  ].freeze

  ENGINE_COUPLING_REFERENCES = [
    /require\s+["']anne_admin/,
    /require\s+["']anne_auth/,
    /\bAnneAdmin::/,
    /\bAnneAuth::/
  ].freeze

  test "runtime files do not reference host application domain constants" do
    runtime_files = Dir[
      AnneAudit::Engine.root.join("app/**/*.rb"),
      AnneAudit::Engine.root.join("lib/anne_audit/**/*.rb")
    ].reject { |path| path.end_with?("/version.rb") }

    violations = runtime_files.filter_map do |path|
      content = File.read(path)
      next unless HOST_DOMAIN_REFERENCES.any? { |pattern| content.match?(pattern) }

      Pathname(path).relative_path_from(AnneAudit::Engine.root).to_s
    end

    assert_empty violations, "Host application constants leaked into runtime files: #{violations.join(", ")}"
  end

  test "core runtime files do not require anne_admin or anne_auth" do
    runtime_files = Dir[
      AnneAudit::Engine.root.join("app/**/*.rb"),
      AnneAudit::Engine.root.join("lib/anne_audit/**/*.rb")
    ].reject do |path|
      path.end_with?("/version.rb") || path.include?("/lib/anne_audit/mappers/")
    end

    violations = runtime_files.filter_map do |path|
      content = File.read(path)
      next unless ENGINE_COUPLING_REFERENCES.any? { |pattern| content.match?(pattern) }

      Pathname(path).relative_path_from(AnneAudit::Engine.root).to_s
    end

    assert_empty violations, "AnneAudit core coupled to existing engines: #{violations.join(", ")}"
  end
end
