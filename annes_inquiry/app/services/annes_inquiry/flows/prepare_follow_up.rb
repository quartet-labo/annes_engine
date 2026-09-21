module AnnesInquiry
  module Flows
    class PrepareFollowUp
      def self.call(root:, version:, context:, request_key:, title:, due_at:, custom: false)
        source = FlowVersion.find(version.id)
        Lock.call(root, extra_versions: [source]) do |current|
          policy = AccessPolicy.for_run(current, context)
          raise Forbidden unless policy.scope(FlowRun.where(id: current.id)).exists?
          policy.authorize!(:admin_view, run: current)
          policy.authorize!(:admin_follow_up, run: current)
          raise Conflict, "初回の受付完了後に追加質問を作成してください。" unless current.submitted? && !current.follow_up_request
          raise Conflict unless due_at.respond_to?(:future?) && due_at.future?
          source.reload
          raise Forbidden unless source.published? && source.flow.follow_up_request_id.nil? && source.flow.enabled?
          existing = current.follow_up_requests.find_by(request_key: request_key)
          if existing
            raise Conflict unless existing.source_version_id == source.id && existing.custom == custom && existing.title == title && existing.due_at.to_i == due_at.to_i
            next existing
          end
          request = current.follow_up_requests.create!(source_version: source, definition_version: source, request_key: request_key, number: (current.follow_up_requests.maximum(:number) || 0) + 1, title: title, due_at: due_at, custom: custom)
          if custom
            request.update!(definition_version: Definitions::CopyForFollowUp.call(source, request))
          end
          request
        end
      end
    end
  end
end
