require "securerandom"

class Customer < ApplicationRecord
  KIND_LABELS = {
    "person" => "個人",
    "organization" => "法人"
  }.freeze

  STATUS_LABELS = {
    "active" => "有効",
    "inactive" => "停止"
  }.freeze

  belongs_to :person, optional: true
  belongs_to :organization, optional: true

  has_many :customer_contacts, dependent: :destroy
  has_many :projects, dependent: :destroy

  before_validation :assign_customer_number, on: :create

  validates :customer_number, presence: true, uniqueness: true
  validates :kind, presence: true, inclusion: { in: KIND_LABELS.keys }
  validates :status, presence: true, inclusion: { in: STATUS_LABELS.keys }
  validate :target_matches_kind

  def display_name
    return "#{target.display_name}（#{kind_label}）" if target

    customer_number
  end

  def kind_label
    KIND_LABELS.fetch(kind, kind)
  end

  def status_label
    STATUS_LABELS.fetch(status, status)
  end

  def target
    case kind
    when "person"
      person
    when "organization"
      organization
    end
  end

  private
    def assign_customer_number
      self.customer_number = "C#{SecureRandom.hex(4).upcase}" if customer_number.blank?
    end

    def target_matches_kind
      case kind
      when "person"
        errors.add(:person, "を選択してください") if person.blank?
        errors.add(:organization, "は個人顧客では選択できません") if organization.present?
      when "organization"
        errors.add(:organization, "を選択してください") if organization.blank?
        errors.add(:person, "は法人顧客では選択できません") if person.present?
      end
    end
end
