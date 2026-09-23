class CreateFlowFollowUpAnswers < ActiveRecord::Migration[8.1]
  def change
    create_table :flow_follow_up_answers do |t|
      t.references :flow_intake_request, null: false, foreign_key: true
      t.bigint :follow_up_request_id, null: false
      t.bigint :run_id, null: false
      t.timestamps
    end
    add_index :flow_follow_up_answers, :follow_up_request_id, unique: true
    add_index :flow_follow_up_answers, :run_id, unique: true
  end
end
