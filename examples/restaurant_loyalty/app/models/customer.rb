require "securerandom"

class Customer < ApplicationRecord
  has_one :loyalty_member,
    class_name: "AnneLoyalty::LoyaltyMember",
    as: :owner,
    dependent: :restrict_with_error
  has_many :receipts, dependent: :restrict_with_error
  has_many :visits, dependent: :restrict_with_error

  before_validation :assign_customer_number, on: :create

  scope :active, -> { where(active: true) }

  validates :customer_number, presence: true, uniqueness: true
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :active, inclusion: { in: [ true, false ] }

  def display_name
    "#{customer_number} #{name}"
  end

  private
    def assign_customer_number
      self.customer_number = "C-#{SecureRandom.hex(4).upcase}" if customer_number.blank?
    end
end
