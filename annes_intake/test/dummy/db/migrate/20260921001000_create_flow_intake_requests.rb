class CreateFlowIntakeRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :flow_intake_requests do |t|
      t.bigint :run_id, null: false
      t.string :customer_key, null: false
      t.timestamps
    end
    add_index :flow_intake_requests, :run_id, unique: true
  end
end
