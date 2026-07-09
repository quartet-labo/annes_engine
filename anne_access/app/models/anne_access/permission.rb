module AnneAccess
  class Permission < ApplicationRecord
    self.table_name = "anne_access_permissions"

    has_many :role_permissions, dependent: :destroy
    has_many :roles, through: :role_permissions

    before_validation :normalize_values
    before_validation :assign_key

    validates :key, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\.[a-z0-9_]+\z/ }
    validates :resource, presence: true
    validates :action, presence: true, uniqueness: { scope: :resource }

    private
      def normalize_values
        self.resource = resource.to_s.strip.downcase if resource
        self.action = action.to_s.strip.downcase if action
      end

      def assign_key
        self.key = "#{resource}.#{action}" if key.blank? && resource.present? && action.present?
        self.key = key.to_s.strip.downcase if key
      end
  end
end
