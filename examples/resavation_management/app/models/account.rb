class Account < AnnesAuth::Account
  has_many :anne_access_assignments,
    as: :principal,
    class_name: "AnneAccess::Assignment",
    dependent: :destroy
  has_many :anne_access_roles,
    through: :anne_access_assignments,
    source: :role
  has_many :canceled_reservations,
    class_name: "Reservation",
    foreign_key: :canceled_by_id,
    inverse_of: :canceled_by,
    dependent: :restrict_with_error
end
