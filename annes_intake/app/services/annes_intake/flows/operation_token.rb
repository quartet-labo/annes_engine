module AnnesIntake
  module Flows
    class OperationToken
      ACTIONS = %w[save complete finalize cancel].freeze
      def self.issue(run:, action:, context:, step: nil, expires_in: AnnesIntake.configuration.operation_token_ttl)
        raise ArgumentError unless ACTIONS.include?(action.to_s)
        policy = AccessPolicy.for_run(run, context)
        policy.authorize!(action, run: run, step: step)
        raise ArgumentError unless expires_in.is_a?(Numeric) || expires_in.is_a?(ActiveSupport::Duration)
        raise ArgumentError unless expires_in.to_f.positive? && expires_in.to_f.finite?
        verifier.generate(binding(run, step, action, policy).merge("revision" => run.revision, "request_key" => SecureRandom.uuid), expires_in: expires_in)
      end

      def self.verify!(token, run:, action:, policy:, step: nil, replay: false)
        data = token.is_a?(String) && verifier.verified(token)
        expected = binding(run, step, action, policy)
        revision = replay ? run.submitted_revision : run.revision
        valid = data.is_a?(Hash) && expected.all? { |key, value| data[key] == value } && data["revision"] == revision &&
          data["request_key"].is_a?(String) && data["request_key"].match?(/\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z/)
        raise Conflict, "送信情報が失効しました。再開して確認し直してください。" unless valid
        data
      end

      def self.binding(run, step, action, policy)
        { "run" => run.id, "step" => step&.id, "version" => run.flow_version_id, "action" => action.to_s,
          "owner" => policy.owner_digest, "context" => policy.context_digest, "epoch" => run.token_epoch }
      end
      def self.verifier = Rails.application.message_verifier("annes-intake-flow-operation-v1")
      private_class_method :binding, :verifier
    end
  end
end
