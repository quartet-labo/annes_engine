module CustomerAccountProfile
  extend ActiveSupport::Concern

  included do
    has_many :customer_account_memberships, dependent: :destroy
    has_many :customers, through: :customer_account_memberships
  end

  def primary_customer
    customer_account_memberships.includes(:customer).order(role: :desc, id: :asc).first&.customer
  end
end
