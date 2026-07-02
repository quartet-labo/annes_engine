class CustomerContact < ApplicationRecord
  ROLE_LABELS = {
    "primary" => "主担当",
    "billing" => "請求担当",
    "technical" => "技術担当",
    "decision_maker" => "決裁者",
    "other" => "その他"
  }.freeze

  belongs_to :customer
  belongs_to :person

  validates :role, presence: true, inclusion: { in: ROLE_LABELS.keys }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :primary, inclusion: { in: [ true, false ] }

  def display_name
    "#{person.display_name}（#{role_label}）"
  end

  def role_label
    ROLE_LABELS.fetch(role, role)
  end
end
