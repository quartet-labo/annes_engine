ActiveRecord::Schema[8.1].define(version: 2026_08_02_000100) do
  create_table "anne_audit_events", force: :cascade do |t|
    t.string "event_id", null: false
    t.string "source", null: false
    t.string "action", null: false
    t.string "result", default: "success", null: false
    t.datetime "occurred_at", null: false
    t.string "actor_type"
    t.string "actor_id"
    t.string "actor_label"
    t.string "target_type"
    t.string "target_id"
    t.string "target_label"
    t.string "request_id"
    t.string "ip_address"
    t.text "user_agent"
    t.json "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index [ "actor_type", "actor_id" ], name: "index_anne_audit_events_on_actor_type_and_actor_id"
    t.index [ "event_id" ], name: "index_anne_audit_events_on_event_id", unique: true
    t.index [ "occurred_at" ], name: "index_anne_audit_events_on_occurred_at"
    t.index [ "request_id" ], name: "index_anne_audit_events_on_request_id"
    t.index [ "result", "occurred_at" ], name: "index_anne_audit_events_on_result_and_occurred_at"
    t.index [ "source", "action" ], name: "index_anne_audit_events_on_source_and_action"
    t.index [ "target_type", "target_id" ], name: "index_anne_audit_events_on_target_type_and_target_id"
  end
end
