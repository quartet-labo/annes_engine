module AnnesIntake
  module Flows
    class AccessPolicy
      attr_reader :adapter, :context, :flow
      def self.for_run(run, context)
        new(flow: run.flow, context: context, run: run)
      end
      def initialize(flow:, context:, run: nil)
        @flow, @context = flow, context
        @adapter = AnnesIntake.configuration.adapters[(run ? run.adapter_flow : flow).key]
        raise Forbidden, "フローへのアクセスを許可できません。" unless adapter && %i[identity context_key authorize!].all? { |method| adapter.respond_to?(method) }
      end

      def owner_digest = digest(adapter.identity(context))
      def context_digest = digest(adapter.context_key(context))

      def authorize!(action, run: nil, step: nil)
        raise Forbidden unless !run || run.flow_version.flow_id == flow.id
        raise Forbidden unless !step || (run && step.run_id == run.id)
        if run && !action.to_s.start_with?("admin_")
          raise ActiveRecord::RecordNotFound unless run.owner_digest == owner_digest && run.context_digest == context_digest
        end
        if run&.follow_up_request
          raise ActiveRecord::RecordNotFound unless scope(Run.where(id: run.id)).exists?
          root = run.follow_up_request.root_run
          raise ActiveRecord::RecordNotFound unless scope(Run.where(id: root.id)).exists?
          root_action = action.to_s.start_with?("admin_") ? :admin_view : :view
          raise Forbidden unless adapter.authorize!(action: root_action, run: root, step: nil, context: context) == true
        end
        allowed = adapter.authorize!(action: action.to_sym, run: run, step: step, context: context)
        raise Forbidden unless allowed == true
        true
      end

      def scope(relation)
        raise Forbidden unless adapter.respond_to?(:scope_runs)
        scoped = adapter.scope_runs(relation, context: context)
        raise Forbidden unless scoped.is_a?(ActiveRecord::Relation) && scoped.klass == Run
        relation.where(id: scoped.select(:id))
      end

      private
        def digest(value)
          raise Forbidden unless value.is_a?(String) && value.present?
          Digest::SHA256.hexdigest(value)
        end
    end
  end
end
