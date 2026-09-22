class CreatePackageRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :package_requests do |t|
      t.bigint :run_id, null: false
    end
    add_index :package_requests, :run_id, unique: true
  end
end
