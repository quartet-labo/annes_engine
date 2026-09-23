# Example host-owned record; the engine never refers to this model.
class FlowIntakeRequest < ActiveRecord::Base
  validates :run_id, uniqueness: true
end
