module AnnesInquiry
  class NotificationRequest < ApplicationRecord
    belongs_to :submission, class_name: "AnnesInquiry::Submission", inverse_of: :notification_requests
    enum :status, { pending: "pending", processing: "processing", sent: "sent", failed: "failed", unknown: "unknown" }, validate: true
    validates :kind, presence: true
    validates :attempts, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
