class CreatePackageFollowUps < ActiveRecord::Migration[8.1]
  def change
    create_table :package_follow_ups do |t|
      t.references :package_request, null: false, foreign_key: true
      t.bigint :follow_up_request_id, null: false
      t.bigint :run_id, null: false
    end
    add_index :package_follow_ups, :follow_up_request_id, unique: true
    add_index :package_follow_ups, :run_id, unique: true
  end
end
