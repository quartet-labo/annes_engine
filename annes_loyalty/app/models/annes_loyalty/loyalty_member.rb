module AnnesLoyalty
  class LoyaltyMember < ApplicationRecord
    self.table_name = "annes_loyalty_loyalty_members"

    belongs_to :loyalty_program
    belongs_to :owner, polymorphic: true
    has_many :loyalty_ledger_entries, dependent: :restrict_with_exception
    has_many :loyalty_point_lots, dependent: :restrict_with_exception
    has_many :loyalty_redemptions, dependent: :restrict_with_exception

    before_validation :normalize_member_key

    validates :member_key, presence: true, uniqueness: { scope: :loyalty_program_id }
    validates :owner_id, uniqueness: { scope: [ :loyalty_program_id, :owner_type ] }
    validates :cached_balance, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :lifetime_earned_points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    scope :active, -> { where(active: true) }

    def display_name
      member_key
    end

    private
      def normalize_member_key
        self.member_key = member_key.to_s.strip if member_key
      end
  end
end
