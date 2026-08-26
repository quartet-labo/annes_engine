module AnnesLoyalty
  class LoyaltyRedemption < ApplicationRecord
    self.table_name = "annes_loyalty_loyalty_redemptions"

    STATUSES = %w[issued redeemed expired canceled].freeze

    belongs_to :loyalty_member
    belongs_to :loyalty_reward
    belongs_to :redeemed_loyalty_location, class_name: "AnnesLoyalty::LoyaltyLocation", optional: true

    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :token_digest, presence: true, uniqueness: true
    validates :issued_at, :expires_at, presence: true
    validate :expires_after_issue

    scope :active_tokens, -> { where(status: "issued").where("expires_at > ?", Time.current) }

    STATUSES.each do |status_name|
      define_method("#{status_name}?") { status == status_name }
    end

    def token_expired?(at: Time.current)
      expires_at <= at
    end

    private
      def expires_after_issue
        return if issued_at.blank? || expires_at.blank?
        return if expires_at > issued_at

        errors.add(:expires_at, "must be after issued at")
      end
  end
end
