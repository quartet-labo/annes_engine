module AnnesIntake
  module Flows
    class FollowUpReader
      def self.call(root:, context:, action: :view)
        policy = AccessPolicy.for_run(root, context)
        raise ActiveRecord::RecordNotFound unless policy.scope(Run.where(id: root.id)).exists?
        policy.authorize!(action, run: root)
        raise Conflict unless root.submitted? && !root.follow_up_request
        requests = root.follow_up_requests.includes(:definition_version, :response_run)
        requests = requests.where.not(issued_at: nil) unless action.to_s.start_with?("admin_")
        requests.to_a.select do |request|
          next true unless request.response_run
          begin
            policy = AccessPolicy.for_run(request.response_run, context)
            next false unless policy.scope(Run.where(id: request.response_run_id)).exists?
            AccessPolicy.for_run(request.response_run, context).authorize!(action, run: request.response_run)
            true
          rescue Forbidden, ActiveRecord::RecordNotFound
            false
          end
        end
      end
    end
  end
end
