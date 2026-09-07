class CreateAnnesInquiryNotificationRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_inquiry_notification_requests do |t|
      t.references :submission, null: false, foreign_key: { to_table: :annes_inquiry_submissions }
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.datetime :sent_at
      t.datetime :processing_started_at
      t.timestamps
    end
    add_index :annes_inquiry_notification_requests, [ :submission_id, :kind ], unique: true, name: "inquiry_notification_kind"
    add_index :annes_inquiry_notification_requests, [ :status, :id ], name: "inquiry_notification_pending"
    add_check_constraint :annes_inquiry_notification_requests, "status IN ('pending','processing','sent','failed','unknown') AND attempts >= 0", name: "inquiry_notification_state"
  end
end
