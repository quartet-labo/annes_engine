module AnnesAccess
  class Role < ApplicationRecord
    self.table_name = "annes_access_roles"

    has_many :assignments, dependent: :destroy
    has_many :role_permissions, dependent: :destroy
    has_many :permissions, through: :role_permissions

    before_validation :normalize_key

    validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/ }
    validates :name, presence: true

    private
      def normalize_key
        self.key = key.to_s.strip.downcase if key
      end
  end
end
