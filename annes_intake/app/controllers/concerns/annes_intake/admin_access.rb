module AnnesIntake
  module AdminAccess
    extend ActiveSupport::Concern

    included do
      include FlowErrors
      before_action :require_intake_administration
      helper AnnesIntake::FormHelper, AnnesIntake::FlowHelper
      helper_method :authorize_definition_contents!
      layout "annes_intake/admin"
    end

    private
      # Aggregate screens must not render a partial schema or evaluate hidden fields.
      def authorize_definition_contents!(version)
        @definition_policy.authorize!(version, action: :admin_view_definition)
        if version.is_a?(FlowVersion)
          version.steps.each { |step| authorize_definition_contents!(step.form_version) }
        else
          version.fields.each { |field| @definition_policy.authorize!(field, action: :admin_view_definition) }
        end
      end

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
        @intake_admin_user = user
        return if is_a?(AnnesIntake::Admin::RunsController) || is_a?(AnnesIntake::Admin::FollowUpsController)
        authorizer = config.definition_authorizer
        raise Flows::Forbidden unless authorizer&.respond_to?(:prepare_context)
        @definition_context = authorizer.prepare_context(self, admin: user)
        return if performed?
        @definition_policy = DefinitionPolicy.new(context: @definition_context)
        @definition_policy.authorize!(nil, action: request.get? || request.head? ? :admin_view_definition : :admin_define)
      end
  end
end
