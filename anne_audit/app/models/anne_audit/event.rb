require "securerandom"

module AnneAudit
  class Event < ApplicationRecord
    self.table_name = "anne_audit_events"

    before_validation :set_event_id, on: :create
    before_validation :set_occurred_at, on: :create
    before_validation :set_metadata

    validates :event_id, :source, :action, :result, :occurred_at, presence: true
    validates :event_id, uniqueness: true

    def readonly?
      persisted?
    end

    private
      def set_event_id
        self.event_id ||= SecureRandom.uuid
      end

      def set_occurred_at
        self.occurred_at ||= Time.current
      end

      def set_metadata
        self.metadata ||= {}
      end
  end
end
