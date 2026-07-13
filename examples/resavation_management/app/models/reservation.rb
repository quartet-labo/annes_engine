require "securerandom"

class Reservation < ApplicationRecord
  include AASM

  STATUS_LABELS = {
    "provisional" => "仮予約",
    "confirmed" => "予約確定",
    "completed" => "利用完了",
    "canceled" => "取消",
    "no_show" => "無断キャンセル"
  }.freeze
  STATUSES = STATUS_LABELS.keys.freeze
  BLOCKING_STATUSES = %w[provisional confirmed].freeze
  TERMINAL_STATUSES = %w[completed canceled no_show].freeze

  CHANNEL_LABELS = {
    "phone" => "電話",
    "email" => "メール",
    "counter" => "窓口",
    "web" => "Web",
    "other" => "その他"
  }.freeze
  CHANNELS = CHANNEL_LABELS.keys.freeze

  belongs_to :customer
  belongs_to :reservation_resource
  belongs_to :canceled_by, class_name: "Account", inverse_of: :canceled_reservations, optional: true

  aasm column: :status, create_scopes: false do
    state :confirmed, initial: true
    state :provisional
    state :completed
    state :canceled
    state :no_show

    event :confirm do
      transitions from: :provisional, to: :confirmed
    end

    event :cancel, before: :assign_aasm_cancellation_metadata do
      transitions from: %i[provisional confirmed], to: :canceled
    end

    event :complete do
      transitions from: :confirmed, to: :completed, guard: :reservation_started?
    end

    event :mark_no_show do
      transitions from: :confirmed, to: :no_show, guard: :reservation_started?
    end
  end

  before_validation :assign_reservation_number, on: :create

  scope :chronological, -> { order(:starts_at, :id) }
  scope :blocking, -> { where(status: BLOCKING_STATUSES) }

  validates :reservation_number, presence: true, uniqueness: true
  validates :starts_at, presence: true
  validates :ends_at, presence: true, comparison: { greater_than: :starts_at }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :party_size, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :channel, presence: true, inclusion: { in: CHANNELS }
  validate :ends_on_same_business_day
  validate :party_size_fits_resource
  validate :active_associations_for_new_assignment
  validate :cancellation_metadata_is_consistent
  validate :time_range_does_not_overlap
  validate :terminal_record_is_immutable, on: :update

  def display_name
    "#{reservation_number} #{customer&.name}"
  end

  def status_label
    STATUS_LABELS.fetch(status, status)
  end

  def channel_label
    CHANNEL_LABELS.fetch(channel, channel)
  end

  def blocking?
    status.in?(BLOCKING_STATUSES)
  end

  def terminal?
    status.in?(TERMINAL_STATUSES)
  end

  private
    def reservation_started?
      starts_at.present? && starts_at <= Time.current
    end

    def assign_aasm_cancellation_metadata(actor, reason = nil, canceled_at = Time.current)
      self.canceled_by = actor
      self.canceled_at = canceled_at
      self.cancellation_reason = reason
    end

    def assign_reservation_number
      self.reservation_number = "R-#{SecureRandom.hex(4).upcase}" if reservation_number.blank?
    end

    def ends_on_same_business_day
      return if starts_at.blank? || ends_at.blank?
      return if starts_at.in_time_zone.to_date == ends_at.in_time_zone.to_date

      errors.add(:ends_at, :same_business_day)
    end

    def party_size_fits_resource
      return unless new_record? || will_save_change_to_party_size? || will_save_change_to_reservation_resource_id?
      return if party_size.blank? || reservation_resource.blank? || reservation_resource.capacity.blank?
      return if party_size <= reservation_resource.capacity

      errors.add(:party_size, :less_than_or_equal_to, count: reservation_resource.capacity)
    end

    def active_associations_for_new_assignment
      if customer.present? && (new_record? || will_save_change_to_customer_id?) && !customer.active?
        errors.add(:customer, :inactive)
      end

      if reservation_resource.present? &&
          (new_record? || will_save_change_to_reservation_resource_id?) &&
          !reservation_resource.active?
        errors.add(:reservation_resource, :inactive)
      end
    end

    def cancellation_metadata_is_consistent
      if status == "canceled"
        errors.add(:canceled_at, :blank) if canceled_at.blank?
        errors.add(:canceled_by, :blank) if canceled_by.blank?
      else
        errors.add(:canceled_at, :present) if canceled_at.present?
        errors.add(:canceled_by, :present) if canceled_by.present?
        errors.add(:cancellation_reason, :present) if cancellation_reason.present?
      end
    end

    def time_range_does_not_overlap
      return unless blocking?
      return if reservation_resource_id.blank? || starts_at.blank? || ends_at.blank? || ends_at <= starts_at

      conflicts = self.class.blocking
        .where(reservation_resource_id: reservation_resource_id)
        .where("starts_at < ? AND ends_at > ?", ends_at, starts_at)
      conflicts = conflicts.where.not(id: id) if persisted?

      errors.add(:starts_at, :overlap) if conflicts.exists?
    end

    def terminal_record_is_immutable
      previous_status = attribute_in_database("status")
      return unless previous_status.in?(TERMINAL_STATUSES)

      changed_attributes = changes_to_save.keys - %w[updated_at lock_version]
      errors.add(:base, :terminal_record) if changed_attributes.any?
    end
end
