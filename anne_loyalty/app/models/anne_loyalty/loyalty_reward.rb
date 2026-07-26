module AnneLoyalty
  class LoyaltyReward < ApplicationRecord
    self.table_name = "anne_loyalty_loyalty_rewards"

    belongs_to :loyalty_program
    has_many :loyalty_redemptions, dependent: :restrict_with_exception

    before_validation :normalize_code

    validates :code, presence: true, uniqueness: { scope: :loyalty_program_id }, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
    validates :name, presence: true
    validates :required_points, numericality: { only_integer: true, greater_than: 0 }
    validates :valid_minutes, numericality: { only_integer: true, greater_than: 0 }

    scope :active, -> { where(active: true) }
    scope :affordable_for, ->(member) { where("required_points <= ?", member.cached_balance) }

    def display_name
      name
    end

    private
      def normalize_code
        self.code = code.to_s.strip.parameterize if code
      end
  end
end
