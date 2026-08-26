require_relative "test_helper"

class AnnesAdmin::PackageBoundaryTest < AnnesAdmin::TestCase
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
  ]

  test "runtime files do not reference host application domain constants" do
    runtime_files = Dir[
      AnnesAdmin::Engine.root.join("app/**/*.rb"),
      AnnesAdmin::Engine.root.join("lib/annes_admin/**/*.rb")
    ].reject { |path| path.end_with?("/version.rb") }

    violations = runtime_files.filter_map do |path|
      content = File.read(path)
      next unless HOST_DOMAIN_REFERENCES.any? { |pattern| content.match?(pattern) }

      Pathname(path).relative_path_from(AnnesAdmin::Engine.root).to_s
    end

    assert_empty violations, "Host application constants leaked into runtime files: #{violations.join(", ")}"
  end
end
