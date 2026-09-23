if ENV["INTAKE_DEMO"] == "true" && Rails.env.test?
  class IntakeDemoDefinitions
    def prepare_context(controller, admin:) = admin
    def scope_definitions(relation, context:) = relation
    def authorize!(action:, record:, context:) = context == :demo_admin
  end
  class IntakeDemoAdapter
    def prepare_context(controller) = "demo-customer"
    def identity(context) = context
    def context_key(context) = "demo"
    def authorize!(action:, run:, step:, context:) = context == "demo-customer"
    def scope_runs(relation, context:) = relation.where(owner_digest: Digest::SHA256.hexdigest(context))
    def run_expires_at(context) = 7.days.from_now
    def persist!(run, answers, context) = FlowIntakeRequest.create!(run_id: run.id, customer_key: context)
    def persist_follow_up!(request, run, answers, context)
      FlowFollowUpAnswer.create!(flow_intake_request: FlowIntakeRequest.find_by!(run_id: request.root_run_id), follow_up_request_id: request.id, run_id: run.id)
    end
    def deliver(request) = :sent
  end
  AnnesIntake.configure do |config|
    config.endpoints_enabled = true
    config.definition_authorizer = IntakeDemoDefinitions.new
    config.admin_authenticator = ->(controller) { :demo_admin }
    config.admin_authorizer = ->(controller, user) { user == :demo_admin }
    config.adapters["consultation"] = IntakeDemoAdapter.new
  end
end
