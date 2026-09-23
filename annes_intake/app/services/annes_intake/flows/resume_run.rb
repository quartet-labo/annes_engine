module AnnesIntake
  module Flows
    class ResumeRun
      def self.call(run:, context:)
        Lock.call(run) do |current|
          AccessPolicy.for_run(current, context).authorize!(:resume, run: current)
          Lock.writable!(current)
          current.update!(token_epoch: current.token_epoch + 1, revision: current.revision + 1)
          current
        end
      end
    end
  end
end
