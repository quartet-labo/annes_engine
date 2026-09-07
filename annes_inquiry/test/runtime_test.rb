require "test_helper"

class RuntimeTest < ActiveSupport::TestCase
  test "uses a separate PostgreSQL test database" do
    assert_equal "PostgreSQL", ActiveRecord::Base.connection.adapter_name
    assert_match(/_test\z/, ActiveRecord::Base.connection_db_config.database)
    assert_not_equal "anne_mark_test", ActiveRecord::Base.connection_db_config.database
    assert ActiveRecord::Base.connection.data_source_exists?("schema_migrations")
  end
end
