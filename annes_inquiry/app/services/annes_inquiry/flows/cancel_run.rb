module AnnesInquiry
  module Flows
    class CancelRun
      def self.call(run:, context:, token:)
        Lock.call(run) do |current|
          policy = AccessPolicy.for_run(current, context)
          policy.authorize!(:cancel, run: current)
          OperationToken.verify!(token, run: current, action: :cancel, policy: policy)
          Lock.writable!(current)
          current.update!(status: "cancelled", revision: current.revision + 1, token_epoch: current.token_epoch + 1)
          if request = current.follow_up_request
            request.update_columns(status: "cancelled", lock_version: request.lock_version + 1, updated_at: Time.current)
          end
          current
        end
      end
    end
  end
end
