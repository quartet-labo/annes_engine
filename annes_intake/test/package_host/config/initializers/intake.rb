class PackageDefinitionAuthorizer
  def prepare_context(controller, admin:) = admin
  def scope_definitions(relation, context:) = relation
  def authorize!(action:, record:, context:) = context == :admin
end
class PackageIntakeAdapter
  def prepare_context(controller) = "package-customer"
  def identity(context) = context
  def context_key(context) = "package-tenant"
  def authorize!(action:, run:, step:, context:) = context == "package-customer"
  def scope_runs(relation, context:) = relation.where(owner_digest: Digest::SHA256.hexdigest(context))
  def run_expires_at(context) = 1.day.from_now
  def persist!(run, answers, context) = PackageRequest.create!(run_id: run.id)
  # The host scopes response runs and their root independently on every access.
  def persist_follow_up!(request, run, answers, context)
    original = PackageRequest.find_by!(run_id: request.root_run_id)
    PackageFollowUp.create!(package_request: original, follow_up_request_id: request.id, run_id: run.id)
  end
  def deliver(request) = :sent
end
AnnesIntake.configure do |config|
  config.endpoints_enabled = true
  config.admin_authenticator = ->(controller) { :admin if controller.request.headers["X-Package-Admin"] == "yes" }
  config.admin_authorizer = ->(controller, user) { user == :admin }
  config.definition_authorizer = PackageDefinitionAuthorizer.new
  config.adapters["package"] = PackageIntakeAdapter.new
end
