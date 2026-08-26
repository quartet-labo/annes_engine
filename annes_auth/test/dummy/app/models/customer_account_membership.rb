class CustomerAccountMembership < ApplicationRecord
  belongs_to :customer_account
  belongs_to :customer
end
