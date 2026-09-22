class CreateAnnesIntakeResponses < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_intake_responses do |t|
      t.references :run, null: false, index: {unique: true}, foreign_key: {to_table: :annes_intake_runs}
      t.timestamps
    end
    add_reference :annes_intake_step_responses, :response, null: false, foreign_key: {to_table: :annes_intake_responses}
    add_column :annes_intake_step_responses, :step_key, :string, null: false
    add_index :annes_intake_step_responses, [:response_id, :step_key], unique: true
    add_column :annes_intake_step_responses, :run_id, :bigint, null: false
    add_column :annes_intake_step_responses, :step_run_id, :bigint, null: false
    add_index :annes_intake_responses, [:id, :run_id], unique: true
    add_index :annes_intake_step_runs, [:id, :run_id, :form_version_id], unique: true, name: "intake_step_run_owner_version"
    add_index :annes_intake_step_responses, [:id, :step_run_id], unique: true
    add_foreign_key :annes_intake_step_responses, :annes_intake_responses, column: [:response_id, :run_id], primary_key: [:id, :run_id], name: "intake_response_run_owner"
    add_foreign_key :annes_intake_step_responses, :annes_intake_step_runs, column: [:step_run_id, :run_id, :form_version_id], primary_key: [:id, :run_id, :form_version_id], name: "intake_response_step_owner"
    add_foreign_key :annes_intake_step_runs, :annes_intake_step_responses, column: [:step_response_id, :id], primary_key: [:id, :step_run_id], name: "intake_step_response_identity"
  end
end
