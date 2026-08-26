module AnnesAccess
  class RolePermission < ApplicationRecord
    self.table_name = "annes_access_role_permissions"

    belongs_to :role
    belongs_to :permission

    validates :permission_id, uniqueness: { scope: :role_id }
  end
end
