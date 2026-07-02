class Person < ApplicationRecord
  self.table_name = "persons"

  has_many :customers, dependent: :destroy
  has_many :customer_contacts, dependent: :destroy

  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  def display_name
    name
  end
end
