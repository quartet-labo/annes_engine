module AnnesInquiry
  module Flows
    class ResumeRun
      def self.call(run:, context:)
        Lock.call(run) do |current|
          AccessPolicy.for_run(current, context).authorize!(:resume, run: current)
          Lock.writable!(current)
          current
        end
      end
    end
  end
end
