require "test_helper"

class AnnesAuth::PackageBoundaryTest < ActiveSupport::TestCase
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

  test "built gem includes the submit guard view partial" do
    gemspec_path = AnnesAuth::Engine.root.join("annes_auth.gemspec").to_s
    spec = Gem::Specification.load(gemspec_path)

    assert_includes spec.files, "app/views/layouts/annes_auth/_submit_guard.html.erb"
  end

  test "runtime files do not reference host application domain constants" do
    runtime_files = Dir[
      AnnesAuth::Engine.root.join("app/**/*.rb"),
      AnnesAuth::Engine.root.join("lib/annes_auth/**/*.rb")
    ].reject { |path| path.end_with?("/version.rb") }

    violations = runtime_files.filter_map do |path|
      content = File.read(path)
      next unless HOST_DOMAIN_REFERENCES.any? { |pattern| content.match?(pattern) }

      Pathname(path).relative_path_from(AnnesAuth::Engine.root).to_s
    end

    assert_empty violations, "Host application constants leaked into runtime files: #{violations.join(", ")}"
  end

  test "runtime files do not require a host Session admin wrapper" do
    runtime_files = Dir[
      AnnesAuth::Engine.root.join("app/**/*.rb"),
      AnnesAuth::Engine.root.join("lib/annes_auth/**/*.rb")
    ].reject { |path| path.end_with?("/version.rb") }

    violations = runtime_files.filter_map do |path|
      content = File.read(path)
      next unless HOST_RUNTIME_COUPLING_REFERENCES.any? { |pattern| content.match?(pattern) }

      Pathname(path).relative_path_from(AnnesAuth::Engine.root).to_s
    end

    assert_empty violations, "Host Session wrapper coupling leaked into runtime files: #{violations.join(", ")}"
  end

  test "runtime files do not reference an admin principal" do
    runtime_files = Dir[
      AnnesAuth::Engine.root.join("app/**/*.rb"),
      AnnesAuth::Engine.root.join("lib/annes_auth/**/*.rb")
    ].reject { |path| path.end_with?("/version.rb") }

    violations = runtime_files.filter_map do |path|
      relative_path = Pathname(path).relative_path_from(AnnesAuth::Engine.root).to_s
      content = File.read(path)
      next unless ADMIN_PRINCIPAL_REFERENCES.any? { |pattern| content.match?(pattern) }

      relative_path
    end

    assert_empty violations, "Admin principal coupling leaked into runtime files: #{violations.join(", ")}"
  end
end
