module AnnesInquiry
  # Persisted in the same transaction that removes the unreferenced blob.
  # Keep the request until all storage objects are deleted, so crashes and
  # temporary storage failures can be recovered by the next cleanup run.
  class BlobDeletion < ApplicationRecord
    def purge!
      raise ArgumentError, "Run storage deletion outside a transaction" if self.class.connection.transaction_open?

      service = ActiveStorage::Blob.services.fetch(service_name)
      service.delete(key)
      service.delete_prefixed("variants/#{key}/") if image?
      destroy!
    end
  end
end
