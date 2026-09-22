module AnnesIntake
  module Flows
    class CancelFollowUp
      def self.call(request:, context:)
        persisted = FollowUpRequest.find(request.id)
        Lock.call(persisted.root_run, extra_versions: [persisted.definition_version]) do |root|
          current = FollowUpRequest.lock.find(persisted.id)
          policy = AccessPolicy.for_run(root, context)
          raise Forbidden unless policy.scope(Run.where(id: root.id)).exists?
          policy.authorize!(:admin_view, run: root)
          policy.authorize!(:admin_cancel_follow_up, run: root)
          next current if current.cancelled?
          raise Conflict, "回答済みの質問は取り消せません。" if current.answered?
          if run = current.response_run
            run.lock!
            raise Conflict if run.submitted?
            run.update!(status: "cancelled", token_epoch: run.token_epoch + 1, revision: run.revision + 1)
          end
          current.update_columns(status: "cancelled", lock_version: current.lock_version + 1, updated_at: Time.current)
          current
        end
      end
    end
  end
end
