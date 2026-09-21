class CreateAnnesInquiryBlobDeletions < ActiveRecord::Migration[8.1]
  def change
    create_table :annes_inquiry_blob_deletions do |t|
      t.string :key, null: false
      t.string :service_name, null: false
      t.boolean :image, null: false, default: false
      t.timestamps
    end
    add_index :annes_inquiry_blob_deletions, [:service_name, :key], unique: true, name: "inquiry_blob_deletion_key"
  end
end
