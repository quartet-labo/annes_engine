require_relative "test_helper"

class AnneLoyalty::PackageBoundaryTest < AnneLoyalty::TestCase
  HOST_DOMAIN_REFERENCES = [
    /\bCustomer\b/,
    /\bProject\b/,
    /\bReservation\b/,
    /\bReceipt\b/,
    /\bVisit\b/,
    /\bOrder\b/,
    /\bRestaurant\b/
  ]

  test "runtime files do not reference host application domain constants" do
    runtime_files = Dir[
      AnneLoyalty::Engine.root.join("app/**/*.rb"),
      AnneLoyalty::Engine.root.join("lib/anne_loyalty/**/*.rb")
    ].reject { |path| path.end_with?("/version.rb") }

    violations = runtime_files.filter_map do |path|
      content = File.read(path)
      next unless HOST_DOMAIN_REFERENCES.any? { |pattern| content.match?(pattern) }

      Pathname(path).relative_path_from(AnneLoyalty::Engine.root).to_s
    end

    assert_empty violations, "Host application constants leaked into runtime files: #{violations.join(", ")}"
  end
end
