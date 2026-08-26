module AnnesAccess
  class Assignment < ApplicationRecord
    self.table_name = "annes_access_assignments"

    belongs_to :principal, polymorphic: true
    belongs_to :role

    validates :role_id, uniqueness: { scope: [ :principal_type, :principal_id ] }
  end
end
