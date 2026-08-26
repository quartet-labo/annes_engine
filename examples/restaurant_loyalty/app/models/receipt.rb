require "securerandom"

class Receipt < ApplicationRecord
  belongs_to :customer
  belongs_to :loyalty_location,
    class_name: "AnnesLoyalty::LoyaltyLocation",
    optional: true

  before_validation :assign_receipt_number, on: :create

  validates :receipt_number, presence: true, uniqueness: true
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :purchased_at, presence: true

  def loyalty_source_key
    receipt_number
  end

  def display_name
    "#{receipt_number} #{amount_cents}円"
  end

  private
    def assign_receipt_number
      self.receipt_number = "R-#{SecureRandom.hex(4).upcase}" if receipt_number.blank?
    end
end
