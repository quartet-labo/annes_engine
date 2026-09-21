module AnnesInquiry
  class FlowRun < ApplicationRecord
    belongs_to :flow_version, class_name: "AnnesInquiry::FlowVersion"
    has_one :follow_up_request, class_name: "AnnesInquiry::FollowUpRequest", foreign_key: :response_run_id
    has_many :follow_up_requests, -> { order(:number) }, class_name: "AnnesInquiry::FollowUpRequest", foreign_key: :root_run_id, dependent: :restrict_with_exception
    def adapter_flow = follow_up_request ? follow_up_request.root_run.flow : flow
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
