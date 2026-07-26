module AnneLoyalty
  class LoyaltyLedgerEntry < ApplicationRecord
    self.table_name = "anne_loyalty_loyalty_ledger_entries"

    ENTRY_TYPES = %w[earn redeem expire adjust reverse].freeze

    belongs_to :loyalty_member
    belongs_to :loyalty_location, optional: true

    before_validation :normalize_idempotency_key

    validates :entry_type, presence: true, inclusion: { in: ENTRY_TYPES }
    validates :points_delta, numericality: { only_integer: true, other_than: 0 }
    validates :occurred_at, presence: true
    validates :source_key, uniqueness: {
      scope: [ :loyalty_member_id, :source_type ],
      conditions: -> { where.not(source_type: nil, source_key: nil) }
    }, allow_nil: true
    validate :source_pair_is_complete

    ENTRY_TYPES.each do |type|
      define_method("#{type}?") { entry_type == type }
    end

    private
      def normalize_idempotency_key
        self.source_type = source_type.to_s.strip.presence if source_type
        self.source_key = source_key.to_s.strip.presence if source_key
      end

      def source_pair_is_complete
        return if source_type.blank? && source_key.blank?
        return if source_type.present? && source_key.present?

        errors.add(:source_key, "must be present with source type")
      end
  end
end
