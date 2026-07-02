class Organization < ApplicationRecord
  has_many :customers, dependent: :destroy

  validates :name, presence: true

  def display_name
    name
  end
end
