module AnnesInquiry
  module Flows
    class ResumeRun
      def self.call(run:, context:)
        Lock.call(run) do |current|
          AccessPolicy.new(flow: current.flow, context: context).authorize!(:resume, run: current)
          Lock.writable!(current)
          current
        end
      end
    end
  end
end
