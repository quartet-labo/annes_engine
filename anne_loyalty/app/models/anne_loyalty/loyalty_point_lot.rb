module AnneLoyalty
  class LoyaltyPointLot < ApplicationRecord
    self.table_name = "anne_loyalty_loyalty_point_lots"

    STATUSES = %w[open consumed expired voided].freeze

    belongs_to :loyalty_member

    validates :original_points, numericality: { only_integer: true, greater_than: 0 }
    validates :remaining_points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :expires_on, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validate :remaining_points_not_greater_than_original

    scope :open, -> { where(status: "open").where("remaining_points > 0") }
    scope :expiring_first, -> { order(:expires_on, :id) }

    STATUSES.each do |status_name|
      define_method("#{status_name}?") { status == status_name }
    end

    private
      def remaining_points_not_greater_than_original
        return if original_points.blank? || remaining_points.blank?
        return if remaining_points <= original_points

        errors.add(:remaining_points, "cannot exceed original points")
      end
  end
end
