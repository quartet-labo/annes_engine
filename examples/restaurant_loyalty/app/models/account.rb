class Account < AnnesAuth::Account
  has_many :annes_access_assignments,
    as: :principal,
    class_name: "AnnesAccess::Assignment",
    dependent: :destroy
  has_many :annes_access_roles,
    through: :annes_access_assignments,
    source: :role
end
