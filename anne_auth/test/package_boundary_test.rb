require "test_helper"

class AnneAuth::PackageBoundaryTest < ActiveSupport::TestCase
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
  HOST_RUNTIME_COUPLING_REFERENCES = [
    /class_name:\s*["'](?:::)?Session["']/,
    /@admin_session_class_name\s*=\s*["']Session["']/
  ]
  ADMIN_PRINCIPAL_REFERENCES = [
    /\bAdminUser\b/,
    /\bAdminSession\b/,
    /\badmin_user_id\b/,
    /\bcurrent_admin_user\b/,
    /\bAdminAuthentication\b/,
    /\bafter_admin_login_path\b/
  ]

  test "runtime files do not reference host application domain constants" do
    runtime_files = Dir[
      AnneAuth::Engine.root.join("app/**/*.rb"),
      AnneAuth::Engine.root.join("lib/anne_auth/**/*.rb")
    ].reject { |path| path.end_with?("/version.rb") }

    violations = runtime_files.filter_map do |path|
      content = File.read(path)
      next unless HOST_DOMAIN_REFERENCES.any? { |pattern| content.match?(pattern) }

      Pathname(path).relative_path_from(AnneAuth::Engine.root).to_s
    end

    assert_empty violations, "Host application constants leaked into runtime files: #{violations.join(", ")}"
  end

  test "runtime files do not require a host Session admin wrapper" do
    runtime_files = Dir[
      AnneAuth::Engine.root.join("app/**/*.rb"),
      AnneAuth::Engine.root.join("lib/anne_auth/**/*.rb")
    ].reject { |path| path.end_with?("/version.rb") }

    violations = runtime_files.filter_map do |path|
      content = File.read(path)
      next unless HOST_RUNTIME_COUPLING_REFERENCES.any? { |pattern| content.match?(pattern) }

      Pathname(path).relative_path_from(AnneAuth::Engine.root).to_s
    end

    assert_empty violations, "Host Session wrapper coupling leaked into runtime files: #{violations.join(", ")}"
  end

  test "runtime files do not reference an admin principal" do
    runtime_files = Dir[
      AnneAuth::Engine.root.join("app/**/*.rb"),
      AnneAuth::Engine.root.join("lib/anne_auth/**/*.rb")
    ].reject { |path| path.end_with?("/version.rb") }

    violations = runtime_files.filter_map do |path|
      relative_path = Pathname(path).relative_path_from(AnneAuth::Engine.root).to_s
      content = File.read(path)
      next unless ADMIN_PRINCIPAL_REFERENCES.any? { |pattern| content.match?(pattern) }

      relative_path
    end

    assert_empty violations, "Admin principal coupling leaked into runtime files: #{violations.join(", ")}"
  end
end
