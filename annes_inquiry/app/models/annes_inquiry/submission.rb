module AnnesInquiry
  class Submission < ApplicationRecord
    belongs_to :form_version, class_name: "AnnesInquiry::FormVersion"
    has_many :answers, class_name: "AnnesInquiry::Answer", inverse_of: :submission, dependent: :restrict_with_exception
    has_many :notification_requests, class_name: "AnnesInquiry::NotificationRequest", inverse_of: :submission, dependent: :restrict_with_exception
    attribute :receipt_id, default: -> { SecureRandom.uuid }
    attribute :request_key, default: -> { SecureRandom.uuid }
    attribute :received_at, default: -> { Time.current }
    validates :receipt_id, :request_key, :received_at, presence: true
    validates :payload_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  end
end
