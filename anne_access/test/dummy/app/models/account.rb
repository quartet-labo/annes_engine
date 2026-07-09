class Account < ApplicationRecord
  has_many :anne_access_assignments, as: :principal, class_name: "AnneAccess::Assignment", dependent: :destroy
  has_many :anne_access_roles, through: :anne_access_assignments, source: :role
end
