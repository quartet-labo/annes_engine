class Project < ApplicationRecord
  STATUS_LABELS = {
    "lead" => "見込み",
    "active" => "進行中",
    "waiting" => "確認待ち",
    "completed" => "完了"
  }.freeze

  belongs_to :customer

  validates :project_number, presence: true, uniqueness: true
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUS_LABELS.keys }

  def display_name
    "#{project_number} #{name}"
  end

  def status_label
    STATUS_LABELS.fetch(status, status)
  end
end
