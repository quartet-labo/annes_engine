class RenameAnneAuditEventsToAnnesAuditEvents < ActiveRecord::Migration[8.1]
  INDEX_NAMES = {
    "index_anne_audit_events_on_event_id" => "index_annes_audit_events_on_event_id",
    "index_anne_audit_events_on_occurred_at" => "index_annes_audit_events_on_occurred_at",
    "index_anne_audit_events_on_source_and_action" => "index_annes_audit_events_on_source_and_action",
    "index_anne_audit_events_on_result_and_occurred_at" => "index_annes_audit_events_on_result_and_occurred_at",
    "index_anne_audit_events_on_actor_type_and_actor_id" => "index_annes_audit_events_on_actor_type_and_actor_id",
    "index_anne_audit_events_on_target_type_and_target_id" => "index_annes_audit_events_on_target_type_and_target_id",
    "index_anne_audit_events_on_request_id" => "index_annes_audit_events_on_request_id"
  }.freeze

  def up
    return unless table_exists?(:anne_audit_events)
    raise ActiveRecord::MigrationError, "Both anne_audit_events and annes_audit_events exist; reconcile audit rows before migrating" if table_exists?(:annes_audit_events)

    rename_table :anne_audit_events, :annes_audit_events
    rename_indexes(INDEX_NAMES)
  end

  def down
    return unless table_exists?(:annes_audit_events)
    raise ActiveRecord::MigrationError, "Both anne_audit_events and annes_audit_events exist; reconcile audit rows before rolling back" if table_exists?(:anne_audit_events)

    rename_indexes(INDEX_NAMES.invert)
    rename_table :annes_audit_events, :anne_audit_events
  end

  private
    def rename_indexes(names)
      names.each do |from, to|
        rename_index :annes_audit_events, from, to if index_name_exists?(:annes_audit_events, from)
      end
    end
end
