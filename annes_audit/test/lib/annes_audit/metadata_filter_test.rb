require_relative "../../test_helper"

class AnnesAudit::MetadataFilterTest < AnnesAudit::TestCase
  test "normalizes symbols and filters sensitive metadata recursively" do
    filtered = AnnesAudit::MetadataFilter.new.call(
      source: :admin,
      nested: {
        reason: :manual,
        password: "password-123",
        plain_token: "token",
        invitation_code: "123456",
        oauth_credential: "secret"
      },
      array: [
        { status: :ok, cookie: "signed-cookie" }
      ]
    )

    assert_equal "admin", filtered.fetch("source")
    assert_equal "manual", filtered.fetch("nested").fetch("reason")
    assert_equal({ "status" => "ok" }, filtered.fetch("array").first)
    refute_includes filtered.fetch("nested"), "password"
    refute_includes filtered.fetch("nested"), "plain_token"
    refute_includes filtered.fetch("nested"), "invitation_code"
    refute_includes filtered.fetch("nested"), "oauth_credential"
  end

  test "uses configured filter keys" do
    AnnesAudit.configure do |config|
      config.metadata_filter_keys += %i[api_key]
    end

    filtered = AnnesAudit::MetadataFilter.new.call(api_key: "secret", visible: "value")

    assert_equal({ "visible" => "value" }, filtered)
  end
end
