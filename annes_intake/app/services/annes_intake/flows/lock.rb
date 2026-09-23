module AnnesIntake
  module Flows
    class Lock
      def self.call(run, extra_versions: [])
        completed = nil
        ApplicationRecord.transaction(requires_new: true) do
          persisted = Run.find(run.id)
          follow_up = persisted.follow_up_request
          root = follow_up ? follow_up.root_run : persisted
          versions = [root.flow_version, persisted.flow_version, *extra_versions].uniq(&:id)
          Flow.where(id: versions.map(&:flow_id)).order(:id).lock.load
          form_ids = FormVersion.where(id: Step.where(flow_version_id: versions.map(&:id)).select(:form_version_id)).pluck(:form_id)
          Form.where(id: form_ids).order(:id).lock.load
          Run.lock.find(root.id)
          follow_up.lock! if follow_up
          current = Run.lock.find(persisted.id)
          completed = yield current
        end
        raise Conflict, "保存が取り消されました。" unless completed
        completed
      end

      def self.writable!(run)
        raise Conflict, "このフローは現在編集できません。" unless run.in_progress? && !run.effective_expired? && run.flow.reload.enabled? && run.adapter_flow.reload.enabled?
        if request = run.follow_up_request
          raise Conflict, "追加質問は取り消されたか期限を過ぎています。" unless request.issued? && !request.expired?
        end
        raise Conflict, "フォームは停止中です。" if Form.where(id: FormVersion.where(id: Step.where(flow_version_id: [run.flow_version_id, run.follow_up_request&.root_run&.flow_version_id].compact).select(:form_version_id)).select(:form_id), enabled: false).exists?
      end
    end
  end
end
