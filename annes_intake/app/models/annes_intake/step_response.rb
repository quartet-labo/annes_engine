module AnnesIntake
  class StepResponse < ApplicationRecord
    belongs_to :response, class_name: "AnnesIntake::Response"
    def touch(*) = raise ActiveRecord::ReadOnlyRecord
    before_update { raise ActiveRecord::ReadOnlyRecord }
    before_destroy { raise ActiveRecord::ReadOnlyRecord }
    belongs_to :form_version, class_name: "AnnesIntake::FormVersion"
    has_many :answers, class_name: "AnnesIntake::Answer", inverse_of: :step_response, dependent: :restrict_with_exception
    attribute :receipt_id, default: -> { SecureRandom.uuid }
    attribute :request_key, default: -> { SecureRandom.uuid }
    attribute :received_at, default: -> { Time.current }
    validates :receipt_id, :request_key, :received_at, presence: true
    validates :payload_digest, format: { with: /\A[0-9a-f]{64}\z/ }
  end
end
