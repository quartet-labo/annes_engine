module AnneAuth
  class AdminUser < ApplicationRecord
    self.table_name = "admin_users"

    has_secure_password

    has_many :sessions, class_name: "::Session", foreign_key: :admin_user_id, dependent: :destroy, inverse_of: :admin_user

    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :email, presence: true, uniqueness: { case_sensitive: false }
    validates :role, presence: true
  end
end
