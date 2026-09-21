# Host-owned append-only link to the existing business request.
class FlowFollowUpAnswer < ActiveRecord::Base
  belongs_to :flow_intake_request
  validates :follow_up_request_id, :flow_run_id, uniqueness: true
end
