class HardenAnnesIntakeFollowUpConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :annes_intake_follow_up_requests, "response_run_id IS NULL OR response_run_id <> root_run_id", name: :intake_follow_up_distinct_run
    add_check_constraint :annes_intake_follow_up_requests, "(status = 'answered' AND answered_at IS NOT NULL) OR (status <> 'answered' AND answered_at IS NULL)", name: :intake_follow_up_answered_at
    add_check_constraint :annes_intake_follow_up_requests, "status <> 'draft' OR (response_run_id IS NULL AND issued_at IS NULL)", name: :intake_follow_up_draft
    add_foreign_key :annes_intake_follow_up_requests, :annes_intake_runs, column: [:response_run_id, :definition_version_id], primary_key: [:id, :flow_version_id], name: :intake_follow_up_response_version
  end
end
