class CustomerAccountProject < ApplicationRecord
  belongs_to :customer_account
  belongs_to :project
end
