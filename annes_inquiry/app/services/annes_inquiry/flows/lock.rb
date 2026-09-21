module AnnesInquiry
  module Flows
    class Lock
      def self.call(run)
        completed = nil
        ApplicationRecord.transaction(requires_new: true) do
          version = FlowRun.find(run.id).flow_version
          Flow.find(version.flow_id).lock!
          form_ids = FormVersion.where(id: version.steps.select(:form_version_id)).pluck(:form_id)
          Form.where(id: form_ids).order(:id).lock.load
          current = FlowRun.lock.find(run.id)
          completed = yield current
        end
        raise Conflict, "保存が取り消されました。" unless completed
        completed
      end

      def self.writable!(run)
        raise Conflict, "このフローは現在編集できません。" unless run.in_progress? && !run.effective_expired? && run.flow.reload.enabled?
        raise Conflict, "フォームは停止中です。" if Form.where(id: FormVersion.where(id: run.flow_version.steps.select(:form_version_id)).select(:form_id), enabled: false).exists?
      end
    end
  end
end
