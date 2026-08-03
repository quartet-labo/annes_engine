require_relative "test_helper"

class AnneAudit::ConfigurationTest < AnneAudit::TestCase
  test "defaults to loose coupling and secret metadata filtering" do
    configuration = AnneAudit.configuration

    assert_equal false, configuration.raise_on_persistence_error
    assert_includes configuration.metadata_filter_keys, :password
    assert_includes configuration.metadata_filter_keys, :token
    assert_includes configuration.metadata_filter_keys, :credential
  end

  test "configure updates settings" do
    AnneAudit.configure do |config|
      config.raise_on_persistence_error = true
      config.metadata_filter_keys += %i[api_key]
    end

    assert_equal true, AnneAudit.configuration.raise_on_persistence_error
    assert_includes AnneAudit.configuration.metadata_filter_keys, :api_key
  end
end
