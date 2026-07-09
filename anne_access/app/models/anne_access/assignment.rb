module AnneAccess
  class Assignment < ApplicationRecord
    self.table_name = "anne_access_assignments"

    belongs_to :principal, polymorphic: true
    belongs_to :role

    validates :role_id, uniqueness: { scope: [ :principal_type, :principal_id ] }
  end
end
