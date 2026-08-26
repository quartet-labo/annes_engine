module CustomerAccountProjectAccess
  extend ActiveSupport::Concern

  included do
    has_many :customer_account_projects, dependent: :destroy
    has_many :accessible_projects, through: :customer_account_projects, source: :project
  end
end
