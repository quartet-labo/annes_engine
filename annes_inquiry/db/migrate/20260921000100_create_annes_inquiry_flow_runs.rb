class CreateAnnesInquiryFlowRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_inquiry_flow_runs do |t|
      t.references :flow_version, null: false, foreign_key: { to_table: :annes_inquiry_flow_versions }
      t.string :owner_digest, null: false, limit: 64
      t.string :context_digest, null: false, limit: 64
      t.uuid :start_key, null: false
      t.uuid :receipt_id, null: false
      t.uuid :final_key
      t.string :payload_digest, limit: 64
      t.string :status, null: false, default: "in_progress"
      t.integer :revision, null: false, default: 0
      t.integer :token_epoch, null: false, default: 0
      t.integer :submitted_revision
      t.datetime :expires_at, null: false
      t.datetime :submitted_at
      t.timestamps
    end
    add_index :annes_inquiry_flow_runs, [:flow_version_id, :owner_digest, :context_digest, :start_key], unique: true, name: "inquiry_flow_start_key"
    add_index :annes_inquiry_flow_runs, :receipt_id, unique: true
    add_index :annes_inquiry_flow_runs, [:id, :flow_version_id], unique: true, name: "inquiry_run_version"
    add_check_constraint :annes_inquiry_flow_runs, "status IN ('in_progress','submitted','cancelled','expired') AND revision >= 0 AND token_epoch >= 0", name: "inquiry_run_state"
    add_check_constraint :annes_inquiry_flow_runs, "(status = 'submitted' AND submitted_at IS NOT NULL AND final_key IS NOT NULL AND payload_digest IS NOT NULL AND submitted_revision IS NOT NULL) OR (status <> 'submitted' AND submitted_at IS NULL AND final_key IS NULL AND payload_digest IS NULL AND submitted_revision IS NULL)", name: "inquiry_run_receipt"
    create_table :annes_inquiry_step_runs do |t|
      t.bigint :flow_run_id, null: false
      t.bigint :flow_version_id, null: false
      t.bigint :flow_step_id, null: false
      t.bigint :form_version_id, null: false
      t.bigint :submission_id
      t.string :status, null: false, default: "draft"
      t.timestamps
    end
    add_index :annes_inquiry_step_runs, [:flow_run_id, :flow_step_id], unique: true
    add_index :annes_inquiry_step_runs, :submission_id, unique: true
    add_index :annes_inquiry_step_runs, [:id, :form_version_id], unique: true, name: "inquiry_step_run_version"
    add_foreign_key :annes_inquiry_step_runs, :annes_inquiry_flow_runs, column: [:flow_run_id, :flow_version_id], primary_key: [:id, :flow_version_id], name: "inquiry_step_run_owner"
    add_foreign_key :annes_inquiry_step_runs, :annes_inquiry_flow_steps, column: [:flow_step_id, :flow_version_id, :form_version_id], primary_key: [:id, :flow_version_id, :form_version_id], name: "inquiry_step_run_definition"
    add_foreign_key :annes_inquiry_step_runs, :annes_inquiry_submissions, column: [:submission_id, :form_version_id], primary_key: [:id, :form_version_id], name: "inquiry_step_submission"
    add_check_constraint :annes_inquiry_step_runs, "status IN ('draft','complete','inactive')", name: "inquiry_step_run_state"
    add_index :annes_inquiry_fields, [:id, :form_version_id], unique: true, name: "inquiry_field_version"
    create_table :annes_inquiry_draft_answers do |t|
      t.bigint :step_run_id, null: false
      t.bigint :form_version_id, null: false
      t.bigint :field_id, null: false
      t.text :raw_value
      t.timestamps
    end
    add_index :annes_inquiry_draft_answers, [:step_run_id, :field_id], unique: true
    add_foreign_key :annes_inquiry_draft_answers, :annes_inquiry_step_runs, column: [:step_run_id, :form_version_id], primary_key: [:id, :form_version_id], name: "inquiry_draft_step"
    add_foreign_key :annes_inquiry_draft_answers, :annes_inquiry_fields, column: [:field_id, :form_version_id], primary_key: [:id, :form_version_id], name: "inquiry_draft_field"
    create_table :annes_inquiry_draft_answer_values do |t|
      t.references :draft_answer, null: false, foreign_key: { to_table: :annes_inquiry_draft_answers }
      t.integer :position, null: false
      t.text :raw_value, null: false
    end
    add_index :annes_inquiry_draft_answer_values, [:draft_answer_id, :position], unique: true
    create_table :annes_inquiry_draft_attachments do |t|
      t.bigint :step_run_id, null: false
      t.bigint :form_version_id, null: false
      t.bigint :field_id, null: false
      t.integer :position, null: false
      t.timestamps
    end
    add_index :annes_inquiry_draft_attachments, [:step_run_id, :field_id, :position], unique: true, name: "inquiry_draft_attachment_order"
    add_foreign_key :annes_inquiry_draft_attachments, :annes_inquiry_step_runs, column: [:step_run_id, :form_version_id], primary_key: [:id, :form_version_id], name: "inquiry_draft_attachment_step"
    add_foreign_key :annes_inquiry_draft_attachments, :annes_inquiry_fields, column: [:field_id, :form_version_id], primary_key: [:id, :form_version_id], name: "inquiry_draft_attachment_field"
    create_table :annes_inquiry_flow_notification_requests do |t|
      t.references :flow_run, null: false, foreign_key: { to_table: :annes_inquiry_flow_runs }
      t.string :event_key, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.datetime :processing_started_at
      t.datetime :sent_at
      t.text :last_error
      t.timestamps
    end
    add_index :annes_inquiry_flow_notification_requests, [:flow_run_id, :event_key], unique: true, name: "inquiry_flow_notification_event"
    add_check_constraint :annes_inquiry_flow_notification_requests, "status IN ('pending','processing','sent','failed','unknown') AND attempts >= 0", name: "inquiry_flow_notification_state"
  end
end
