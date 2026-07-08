module AnneAuth
  class User < ApplicationRecord
    self.table_name = "users"

    has_secure_password

    has_many :sessions,
      class_name: AnneAuth.configuration.session_class_name,
      foreign_key: AnneAuth.configuration.session_user_foreign_key,
      dependent: :destroy,
      inverse_of: :user

    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :email, presence: true, uniqueness: { case_sensitive: false }

    scope :active, -> { column_names.include?("disabled_at") ? where(disabled_at: nil) : all }

    def disabled?
      respond_to?(:disabled_at) && disabled_at.present?
    end
  end
end
