module AnnesInquiry
  class FlowNotificationRequest < ApplicationRecord
    belongs_to :flow_run, class_name: "AnnesInquiry::FlowRun"
    enum :status, { pending: "pending", processing: "processing", sent: "sent", failed: "failed", unknown: "unknown" }, validate: true
    validates :event_key, presence: true
  end
end
