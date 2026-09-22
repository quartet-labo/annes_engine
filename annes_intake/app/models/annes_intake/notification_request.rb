module AnnesIntake
  class NotificationRequest < ApplicationRecord
    belongs_to :run, class_name: "AnnesIntake::Run"
    enum :status, { pending: "pending", processing: "processing", sent: "sent", failed: "failed", unknown: "unknown" }, validate: true
    validates :event_key, presence: true
  end
end
