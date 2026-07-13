class ReservationResource < ApplicationRecord
  KIND_LABELS = {
    "facility" => "施設",
    "room" => "部屋",
    "equipment" => "設備",
    "staff" => "担当者",
    "other" => "その他"
  }.freeze

  has_many :reservations, dependent: :restrict_with_error

  scope :active, -> { where(active: true) }

  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: KIND_LABELS.keys }
  validates :capacity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :active, inclusion: { in: [ true, false ] }
  validate :capacity_supports_future_blocking_reservations, on: :update

  def display_name
    name
  end

  def kind_label
    KIND_LABELS.fetch(kind, kind)
  end

  private
    def capacity_supports_future_blocking_reservations
      return unless will_save_change_to_capacity?
      return if capacity.blank? || capacity >= capacity_in_database

      required_capacity = reservations.blocking.where("ends_at > ?", Time.current).maximum(:party_size)
      return if required_capacity.blank? || capacity >= required_capacity

      errors.add(:capacity, :greater_than_or_equal_to, count: required_capacity)
    end
end
