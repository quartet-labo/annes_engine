require "test_helper"

class EngineTest < ActiveSupport::TestCase
  test "loads an isolated engine without host domain models" do
    assert AnnesInquiry::Engine.isolated?
    assert_equal "0.1.0", AnnesInquiry::VERSION
    assert_not Object.const_defined?(:Customer)
    assert_not Object.const_defined?(:Project)
    assert_not Object.const_defined?(:AnnesAuth)
    Rails.application.eager_load!
  end

  test "keeps configuration across a reload" do
    configuration = AnnesInquiry.configuration
    Rails.application.reloader.reload!
    assert_same configuration, AnnesInquiry.configuration
  end

  test "does not enable public endpoints by default" do
    assert_not AnnesInquiry.configuration.public_endpoints_enabled
  end
end
