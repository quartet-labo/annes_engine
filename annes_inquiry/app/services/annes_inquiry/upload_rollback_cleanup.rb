module AnnesInquiry
  class UploadRollbackCleanup
    def self.register(blob)
      attributes = blob.attributes.except("id")
      ActiveRecord::Base.current_transaction.after_rollback { call(attributes) }
    end

    def self.call(attributes)
      return if ActiveStorage::Blob.exists?(key: attributes.fetch("key"))
      begin
        ActiveStorage::Blob.services.fetch(attributes.fetch("service_name")).delete(attributes.fetch("key"))
      rescue StandardError => error
        # Keep a durable candidate when storage is down. No answer references this upload.
        candidate = ActiveStorage::Blob.create!(attributes)
        register(candidate)
        Rails.logger.warn("AnnesInquiry upload cleanup deferred: #{error.class}")
      end
    end
    private_class_method :call
  end
end
