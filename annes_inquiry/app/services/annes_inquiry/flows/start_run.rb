module AnnesInquiry
  module Flows
    class StartRun
      def self.call(flow:, context:, request_key: SecureRandom.uuid)
        raise Conflict unless request_key.is_a?(String) && request_key.match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/)
        policy = AccessPolicy.new(flow: flow, context: context)
        policy.authorize!(:start)
        Flow.find(flow.id).with_lock do
          flow.reload
          raise Conflict unless flow.enabled?
          version = flow.published_version or raise Conflict
          form_ids = FormVersion.where(id: version.steps.select(:form_version_id)).pluck(:form_id)
          forms = Form.where(id: form_ids).order(:id).lock.to_a
          raise Conflict if forms.any? { |form| !form.enabled? }
          existing = FlowRun.joins(:flow_version).where(annes_inquiry_flow_versions: {flow_id: flow.id}, owner_digest: policy.owner_digest, context_digest: policy.context_digest, start_key: request_key).first
          if existing
            policy.authorize!(:view, run: existing)
            return existing
          end
          raise Forbidden unless policy.adapter.respond_to?(:run_expires_at)
          expires = policy.adapter.run_expires_at(context)
          raise Conflict, "有効期限を設定してください。" unless expires.respond_to?(:future?) && expires.future?
          run = FlowRun.create!(flow_version: version, owner_digest: policy.owner_digest, context_digest: policy.context_digest, start_key: request_key, expires_at: expires)
          version.steps.each do |step|
            run.step_runs.create!(flow_step: step, flow_version_id: version.id, form_version_id: step.form_version_id)
          end
          run
        end
      end
    end
  end
end
