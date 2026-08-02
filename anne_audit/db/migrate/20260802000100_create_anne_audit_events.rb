class CreateAnneAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :anne_audit_events do |t|
      t.string :event_id, null: false
      t.string :source, null: false
      t.string :action, null: false
      t.string :result, null: false, default: "success"
      t.datetime :occurred_at, null: false

      t.string :actor_type
      t.string :actor_id
      t.string :actor_label

      t.string :target_type
      t.string :target_id
      t.string :target_label

      t.string :request_id
      t.string :ip_address
      t.text :user_agent

      t.json :metadata, null: false, default: {}
      t.timestamps

      t.index :event_id, unique: true
      t.index :occurred_at
      t.index [ :source, :action ]
      t.index [ :result, :occurred_at ]
      t.index [ :actor_type, :actor_id ]
      t.index [ :target_type, :target_id ]
      t.index :request_id
    end
  end
end
