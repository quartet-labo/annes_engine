require "test_helper"
require "json"

class StandalonePublicContractTest < ActiveSupport::TestCase
  test "published migration and standalone configuration remain compatible" do
    fixture = File.expand_path("../fixtures/compatibility_v0_1_0/migrations.json", __dir__)
    expected = JSON.parse(File.read(fixture))
    actual = Dir[AnnesInquiry::Engine.root.join("db/migrate/*.rb")].to_h { |path| [File.basename(path), Digest::SHA256.file(path).hexdigest] }
    assert_equal expected, actual
    assert_not AnnesInquiry.configuration.public_endpoints_enabled
    assert_not AnnesInquiry.configuration.respond_to?(:flow_adapters)
    assert_not AnnesInquiry::Form.column_names.include?("follow_up_request_id")
    assert_empty ActiveRecord::Base.connection.tables.grep(/annes_intake/)
  end

  test "legacy signature and typed enrichment continue to submit and replay" do
    form = AnnesInquiry::Form.create!(key: "compat", name: "Compatibility")
    version = form.versions.create!(number: 1, title: "Compatibility")
    version.fields.create!(key: "quantity", label: "Quantity", value_type: "integer", widget: "number", required: true)
    version.fields.create!(key: "name", label: "Name", required: true)
    AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    # The 0.1.0 wire contract, independent of the current token issuer.
    token = Rails.application.message_verifier("annes-inquiry-submission-v1").generate(
      {"form_id" => form.id, "version_id" => version.id, "request_key" => SecureRandom.uuid,
       "identity" => Digest::SHA256.hexdigest("customer")}, expires_in: 2.hours)
    calls = []
    adapter = Object.new
    adapter.define_singleton_method(:validate_raw_input) { |raw, _| calls << [:raw, raw.fetch("quantity")]; {} }
    adapter.define_singleton_method(:enrich_input) { |values, _| calls << [:enrich, values.fetch("quantity")]; values.merge("name" => "Trusted") }
    adapter.define_singleton_method(:validate_input) { |values, _| calls << [:typed, values.fetch("name")]; {} }
    options = {form: form, token: token, identity: "customer", raw_values: {"quantity" => "0"}, adapter: adapter}
    result = AnnesInquiry::SubmissionService.call(**options)
    assert result.success?, result.input.errors.full_messages.inspect
    assert_equal [[:raw, "0"], [:enrich, 0], [:typed, "Trusted"]], calls
    assert_instance_of AnnesInquiry::Input, result.input
    assert_instance_of ActiveModel::Errors, result.input.errors
    assert_equal({"quantity" => 0, "name" => "Trusted"}, AnnesInquiry::AnswerReader.new(result.submission).to_h)
    assert_no_difference "AnnesInquiry::Submission.count" do
      replay = AnnesInquiry::SubmissionService.call(**options)
      assert replay.replayed?
      assert_equal result.submission.id, replay.submission.id
    end
  end
  test "enrichment may omit optional keys without changing persisted payload digest" do
    form = AnnesInquiry::Form.create!(key: "omitted", name: "Omitted")
    version = form.versions.create!(number: 1, title: "Omitted")
    version.fields.create!(key: "name", label: "Name")
    AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
    adapter = Object.new
    adapter.define_singleton_method(:enrich_input) { |values, _| values.except("name") }
    input = AnnesInquiry::Input.new(version, raw_values: {"name" => "ignored"}, adapter: adapter)
    assert input.valid?
    assert_equal({}, input.values)
  end

end
