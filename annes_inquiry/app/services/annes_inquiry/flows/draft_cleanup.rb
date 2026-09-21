module AnnesInquiry
  module Flows
    class DraftCleanup
      def self.candidates
        FlowRun.where(status: %w[cancelled expired submitted]).or(FlowRun.where(status: "in_progress").where("expires_at <= ?", Time.current))
      end

      def self.call
        candidates.find_each do |run|
          Lock.call(run) do |current|
            next current unless current.submitted? || current.cancelled? || current.effective_expired?
            current.step_runs.each do |step|
              step.draft_answers.destroy_all
              step.draft_attachments.destroy_all
            end
            current.update!(status: "expired", token_epoch: current.token_epoch + 1) if current.in_progress?
            current
          end
        end
      end
    end
  end
end
