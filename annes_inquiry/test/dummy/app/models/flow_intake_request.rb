# Example host-owned record; the engine never refers to this model.
class FlowIntakeRequest < ActiveRecord::Base
  validates :flow_run_id, uniqueness: true
end
