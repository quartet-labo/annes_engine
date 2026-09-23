class CreateAnnesIntakeFollowUps < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_intake_follow_up_requests do |t|
      t.references :root_run, null: false, foreign_key: {to_table: :annes_intake_runs}
      t.references :definition_version, null: false, foreign_key: {to_table: :annes_intake_flow_versions}
      t.references :source_version, null: false, foreign_key: {to_table: :annes_intake_flow_versions}
      t.references :response_run, foreign_key: {to_table: :annes_intake_runs}, index: {unique: true}
      t.uuid :request_key, null: false
      t.integer :number, null: false
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.boolean :custom, null: false, default: false
      t.datetime :due_at, null: false
      t.datetime :issued_at
      t.datetime :answered_at
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :annes_intake_follow_up_requests, [:root_run_id, :number], unique: true, name: :intake_follow_up_number
    add_index :annes_intake_follow_up_requests, [:root_run_id, :request_key], unique: true, name: :intake_follow_up_request_key
    add_check_constraint :annes_intake_follow_up_requests, "number > 0 AND status IN ('draft','issued','answered','cancelled')", name: :intake_follow_up_status
    add_check_constraint :annes_intake_follow_up_requests, "(status IN ('issued','answered') AND response_run_id IS NOT NULL AND issued_at IS NOT NULL) OR status IN ('draft','cancelled')", name: :intake_follow_up_response
    add_reference :annes_intake_forms, :follow_up_request, foreign_key: {to_table: :annes_intake_follow_up_requests}
    add_reference :annes_intake_flows, :follow_up_request, foreign_key: {to_table: :annes_intake_follow_up_requests}
    add_reference :annes_intake_notification_requests, :follow_up_request, foreign_key: {to_table: :annes_intake_follow_up_requests}
  end
end
