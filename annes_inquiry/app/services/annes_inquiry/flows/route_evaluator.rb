module AnnesInquiry
  module Flows
    class RouteEvaluator
      def self.call(run)
        run.step_runs.joins(:flow_step).order("annes_inquiry_flow_steps.position", :id).to_a
      end
    end
  end
end
