module AnnesInquiry
  class UnattachedBlobCleanup
    def self.candidates(before: 1.day.ago)
      raise ArgumentError, "Uploads need at least one day of grace" if before > 1.day.ago
      ActiveStorage::Blob.unattached.where("active_storage_blobs.created_at < ?", before).find_each.lazy.select do |blob|
        blob.metadata["annes_inquiry"] == true
      end
    end

    def self.call(before: 1.day.ago)
      raise ArgumentError, "Run cleanup outside a transaction" if ApplicationRecord.connection.transaction_open?
      pending_blobs = candidates(before: before)
      BlobDeletion.find_each(&:purge!)
      pending_blobs.each do |blob|
        blob.with_lock do
          next if blob.attachments.exists?

          deletion = BlobDeletion.create!(key: blob.key, service_name: blob.service_name, image: blob.image?)
          blob.destroy!
          ApplicationRecord.connection.current_transaction.after_commit { deletion.purge! }
        end
      end
    end
  end
end
