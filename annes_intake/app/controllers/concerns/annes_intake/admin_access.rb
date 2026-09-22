module AnnesIntake
  module AdminAccess
    extend ActiveSupport::Concern

    included do
      include FlowErrors
      before_action :require_intake_administration
      helper AnnesIntake::FormHelper, AnnesIntake::FlowHelper
      layout "annes_intake/admin"
    end

    private
      def definition_record(record)
        @definition_policy.authorize!(record, action: request.get? || request.head? ? :admin_view_definition : :admin_define)
        record
      end
      def require_intake_administration
        config = AnnesIntake.configuration
        user = config.admin_authenticator&.call(self)
        return if performed?
        unless user && config.admin_authorizer&.call(self, user) == true
          head :forbidden
          return
        end
        response.headers["Cache-Control"] = "private, no-store"
        return if is_a?(AnnesIntake::Admin::RunsController)
        authorizer = config.definition_authorizer
        raise Flows::Forbidden unless authorizer&.respond_to?(:prepare_context)
        @definition_context = authorizer.prepare_context(self, admin: user)
        return if performed?
        @definition_policy = DefinitionPolicy.new(context: @definition_context)
        @definition_policy.authorize!(nil, action: request.get? || request.head? ? :admin_view_definition : :admin_define)
      end
  end
end
