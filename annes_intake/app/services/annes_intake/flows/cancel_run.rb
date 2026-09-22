module AnnesIntake
  module Flows
    class CancelRun
      def self.call(run:, context:, token:)
        Lock.call(run) do |current|
          policy = AccessPolicy.new(flow: current.flow, context: context)
          policy.authorize!(:cancel, run: current)
          OperationToken.verify!(token, run: current, action: :cancel, policy: policy)
          Lock.writable!(current)
          current.update!(status: "cancelled", revision: current.revision + 1, token_epoch: current.token_epoch + 1)
          current
        end
      end
    end
  end
end
