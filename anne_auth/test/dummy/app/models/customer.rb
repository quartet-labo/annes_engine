class Customer < ApplicationRecord
  has_many :customer_account_memberships, dependent: :destroy
  has_many :customer_accounts, through: :customer_account_memberships
  has_many :projects, dependent: :destroy

  def display_name
    company_name.presence || contact_name
  end
end
