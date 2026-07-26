module AnneLoyalty
  class LoyaltyLocation < ApplicationRecord
    self.table_name = "anne_loyalty_loyalty_locations"

    belongs_to :loyalty_program
    has_many :loyalty_ledger_entries, dependent: :restrict_with_exception
    has_many :loyalty_redemptions,
      class_name: "AnneLoyalty::LoyaltyRedemption",
      foreign_key: :redeemed_loyalty_location_id,
      dependent: :restrict_with_exception,
      inverse_of: :redeemed_loyalty_location

    before_validation :normalize_code

    validates :code, presence: true, uniqueness: { scope: :loyalty_program_id }, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
    validates :name, presence: true
    validates :time_zone, presence: true
    validate :time_zone_is_known

    scope :active, -> { where(active: true) }

    def display_name
      name
    end

    private
      def normalize_code
        self.code = code.to_s.strip.parameterize if code
      end

      def time_zone_is_known
        return if time_zone.blank?
        return if ActiveSupport::TimeZone[time_zone]

        errors.add(:time_zone, "is not supported")
      end
  end
end
