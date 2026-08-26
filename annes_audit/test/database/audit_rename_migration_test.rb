require_relative "../test_helper"
require File.expand_path("../../db/migrate/20260826002000_rename_anne_audit_events_to_annes_audit_events", __dir__)

class AuditRenameMigrationTest < ActiveSupport::TestCase
  setup do
    connection.drop_table(:annes_audit_events) if connection.table_exists?(:annes_audit_events)
    connection.create_table :anne_audit_events do |table|
      table.string :event_id, null: false
      table.string :source, null: false
      table.string :action, null: false
      table.string :result, null: false, default: "success"
      table.datetime :occurred_at, null: false
    end
    connection.add_index :anne_audit_events, :event_id, unique: true
    connection.execute <<~SQL
      INSERT INTO anne_audit_events (event_id, source, action, result, occurred_at)
      VALUES ('legacy-event', 'host', 'created', 'success', CURRENT_TIMESTAMP)
    SQL
  end

  teardown do
    connection.drop_table(:anne_audit_events) if connection.table_exists?(:anne_audit_events)
    connection.drop_table(:annes_audit_events) if connection.table_exists?(:annes_audit_events)
    load File.expand_path("../dummy/db/schema.rb", __dir__)
  end

  test "renames legacy events and indexes reversibly" do
    migration.up

    assert connection.table_exists?(:annes_audit_events)
    assert_equal 1, connection.select_value("SELECT COUNT(*) FROM annes_audit_events WHERE event_id = 'legacy-event'").to_i
    assert connection.index_name_exists?(:annes_audit_events, "index_annes_audit_events_on_event_id")

    migration.down

    assert connection.table_exists?(:anne_audit_events)
    assert_equal 1, connection.select_value("SELECT COUNT(*) FROM anne_audit_events WHERE event_id = 'legacy-event'").to_i
    assert connection.index_name_exists?(:anne_audit_events, "index_anne_audit_events_on_event_id")
  end

  private
    def connection
      ActiveRecord::Base.connection
    end

    def migration
      RenameAnneAuditEventsToAnnesAuditEvents.new
    end
end
