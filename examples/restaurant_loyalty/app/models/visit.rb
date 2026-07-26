class Visit < ApplicationRecord
  belongs_to :customer
  belongs_to :loyalty_location,
    class_name: "AnneLoyalty::LoyaltyLocation",
    optional: true

  validates :visited_at, presence: true
end
