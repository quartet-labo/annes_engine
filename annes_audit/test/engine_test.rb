require_relative "test_helper"

class AnnesAudit::EngineTest < AnnesAudit::TestCase
  test "engine is isolated and configured" do
    assert_equal "annes_audit", AnnesAudit::Engine.engine_name
    assert_instance_of AnnesAudit::Configuration, AnnesAudit.configuration
  end

  test "exposes only the AnnesAudit public package contract" do
    assert_equal "1.0.0", AnnesAudit::VERSION
    refute Object.const_defined?(:AnneAudit)
    assert_raises(LoadError) { require "anne_audit" }
  end
end
