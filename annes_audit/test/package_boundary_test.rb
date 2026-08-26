require_relative "test_helper"

class AnnesAudit::PackageBoundaryTest < AnnesAudit::TestCase
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
    /require\s+["']annes_admin/,
    /require\s+["']annes_auth/,
    /\bAnnesAdmin::/,
    /\bAnnesAuth::/
  ].freeze

  test "runtime files do not reference host application domain constants" do
    runtime_files = Dir[
      AnnesAudit::Engine.root.join("app/**/*.rb"),
      AnnesAudit::Engine.root.join("lib/annes_audit/**/*.rb")
    ].reject { |path| path.end_with?("/version.rb") }

    violations = runtime_files.filter_map do |path|
      content = File.read(path)
      next unless HOST_DOMAIN_REFERENCES.any? { |pattern| content.match?(pattern) }

      Pathname(path).relative_path_from(AnnesAudit::Engine.root).to_s
    end

    assert_empty violations, "Host application constants leaked into runtime files: #{violations.join(", ")}"
  end

  test "core runtime files do not require annes_admin or annes_auth" do
    runtime_files = Dir[
      AnnesAudit::Engine.root.join("app/**/*.rb"),
      AnnesAudit::Engine.root.join("lib/annes_audit/**/*.rb")
    ].reject do |path|
      path.end_with?("/version.rb") || path.include?("/lib/annes_audit/mappers/")
    end

    violations = runtime_files.filter_map do |path|
      content = File.read(path)
      next unless ENGINE_COUPLING_REFERENCES.any? { |pattern| content.match?(pattern) }

      Pathname(path).relative_path_from(AnnesAudit::Engine.root).to_s
    end

    assert_empty violations, "AnnesAudit core coupled to existing engines: #{violations.join(", ")}"
  end
end
