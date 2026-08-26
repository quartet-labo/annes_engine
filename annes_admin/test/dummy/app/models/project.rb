class Project < ApplicationRecord
  STATUSES = {
    "received" => "受付",
    "reviewing" => "確認中"
  }.freeze

  belongs_to :customer
end
