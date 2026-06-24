class Customer < ApplicationRecord
  has_many :projects, dependent: :destroy

  validates :contact_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def display_name
    company_name.presence || contact_name
  end
end
