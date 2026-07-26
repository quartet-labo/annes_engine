module AnneLoyalty
  class LoyaltyProgram < ApplicationRecord
    self.table_name = "anne_loyalty_loyalty_programs"

    has_many :loyalty_locations, dependent: :restrict_with_exception
    has_many :loyalty_members, dependent: :restrict_with_exception

    before_validation :normalize_code

    validates :code, presence: true, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
    validates :name, :point_name, presence: true
    validates :earn_unit_amount_cents, numericality: { only_integer: true, greater_than: 0 }
    validates :earn_points_per_unit, numericality: { only_integer: true, greater_than: 0 }
    validates :default_expiration_months, numericality: { only_integer: true, greater_than: 0 }

    scope :active, -> { where(active: true) }

    private
      def normalize_code
        self.code = code.to_s.strip.parameterize if code
      end
  end
end
