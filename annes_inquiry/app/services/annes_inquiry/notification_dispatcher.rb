module AnnesInquiry
  class NotificationDispatcher
    def self.call(id)
      connection = ApplicationRecord.connection_pool.active_connection?
      if connection&.transaction_open?
        # Non-joinable transactions are excluded by after_all_transactions_commit.
        # Register on the actual transaction so the callback cannot recurse early.
        connection.current_transaction.after_commit { call(id) }
        return
      end
      request = NotificationRequest.find_by(id: id)
      return unless request
      claimed = false
      request.with_lock do
        if request.pending?
          request.update!(status: "processing", attempts: request.attempts + 1, processing_started_at: Time.current)
          claimed = true
        end
      end
      return unless claimed

      adapter = AnnesInquiry.configuration.adapters[request.submission.form_version.form.key]
      outcome = adapter&.respond_to?(:deliver) ? adapter.deliver(request) : :failed
      status = %i[sent failed unknown].include?(outcome) ? outcome.to_s : "unknown"
      request.update!(status: status, sent_at: status == "sent" ? Time.current : nil,
        last_error: status == "sent" ? nil : "Notification adapter returned #{status}")
    rescue StandardError => error
      # Exceptions can occur after the external delivery; never assume it was unsent.
      begin
        request&.update!(status: "unknown", last_error: error.class.name) if claimed
      rescue StandardError => state_error
        Rails.logger.error("AnnesInquiry notification state #{id}: #{state_error.class}")
      end
      Rails.logger.error("AnnesInquiry notification #{id}: #{error.class}")
    end

    def self.recover!(stale_before: 1.hour.ago)
      NotificationRequest.processing.where("processing_started_at < ?", stale_before)
        .update_all(status: "unknown", last_error: "Processing interrupted; delivery must be checked", updated_at: Time.current)
      NotificationRequest.pending.find_each { |request| call(request.id) }
    end
  end
end
