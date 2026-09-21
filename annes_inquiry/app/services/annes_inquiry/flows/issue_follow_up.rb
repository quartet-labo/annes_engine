module AnnesInquiry
  module Flows
    class IssueFollowUp
      def self.call(request:, context:, expected_lock_version:, expected_definition_digest:)
        persisted = FollowUpRequest.find(request.id)
        Lock.call(persisted.root_run, extra_versions: [persisted.definition_version]) do |root|
          current = FollowUpRequest.lock.find(persisted.id)
          policy = AccessPolicy.for_run(root, context)
          raise Forbidden unless policy.scope(FlowRun.where(id: root.id)).exists?
          policy.authorize!(:admin_view, run: root)
          policy.authorize!(:admin_follow_up, run: root)
          next current.response_run if current.issued? || current.answered?
          raise Conflict unless current.draft? && !current.expired? && root.submitted? && !root.follow_up_request
          raise Conflict, "質問が更新されました。画面を開き直してください。" unless Integer(expected_lock_version, exception: false) == current.lock_version
          raise Conflict, "質問の定義が更新されました。再度プレビューしてください。" unless expected_definition_digest == FollowUpDefinitionDigest.call(current)
          raise Conflict unless root.flow.enabled?
          version = current.definition_version
          if current.custom?
            raise Forbidden unless version.flow.follow_up_request_id == current.id
            version.steps.map(&:form_version).uniq(&:id).each do |form_version|
              raise Forbidden unless form_version.form.follow_up_request_id == current.id
              AnnesInquiry::Definitions::PublishVersion.call(form_version, expected_lock_version: form_version.lock_version) if form_version.draft?
            end
            Definitions::PublishVersion.call(version, expected_lock_version: version.lock_version) if version.draft?
          end
          version.reload
          raise Conflict unless !version.draft? && version.flow.enabled?
          # Pinned published form versions may later be retired; disabling remains a stop switch.
          raise Conflict if version.steps.any? { |step| !step.form_version.form.enabled? }
          run = FlowRun.create!(flow_version: version, owner_digest: root.owner_digest, context_digest: root.context_digest, start_key: SecureRandom.uuid, expires_at: current.due_at)
          version.steps.each { |step| run.step_runs.create!(flow_step: step, flow_version_id: version.id, form_version_id: step.form_version_id) }
          current.update!(status: "issued", response_run: run, issued_at: Time.current)
          RouteEvaluator.reconcile!(run)
          if policy.adapter.respond_to?(:deliver)
            notification = root.notification_requests.create!(event_key: "follow_up:#{current.id}:issued", follow_up_request: current)
            ActiveRecord.after_all_transactions_commit { NotificationDispatcher.call(notification.id) }
          end
          run
        end
      end
    end
  end
end
