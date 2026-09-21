module AnnesInquiry
  class FlowRun < ApplicationRecord
    belongs_to :flow_version, class_name: "AnnesInquiry::FlowVersion"
    has_one :flow, through: :flow_version
    has_many :step_runs, class_name: "AnnesInquiry::StepRun", dependent: :restrict_with_exception
    has_many :notification_requests, class_name: "AnnesInquiry::FlowNotificationRequest", dependent: :restrict_with_exception
    enum :status, { in_progress: "in_progress", submitted: "submitted", cancelled: "cancelled", expired: "expired" }, validate: true
    attribute :receipt_id, default: -> { SecureRandom.uuid }
    validates :owner_digest, :context_digest, :start_key, :expires_at, presence: true
    before_update :preserve_receipt
    def effective_expired? = expired? || (!submitted? && expires_at <= Time.current)

    private
      def preserve_receipt
        throw :abort if status_in_database == "submitted"
      end
  end
end
