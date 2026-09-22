module FlowTestSupport
  class Adapter
    attr_accessor :failure
    attr_reader :persisted, :delivered
    def initialize
      @persisted, @delivered = [], []
    end
    def prepare_context(controller)
      { identity: controller.request.headers["X-Flow-Identity"].presence || "alice", allowed: true }
    end
    def identity(context) = context.fetch(:identity)
    def context_key(context) = "tenant-1"
    def run_expires_at(context) = 7.days.from_now
    def authorize!(action:, run:, step:, context:)
      raise AnnesIntake::Flows::Forbidden unless context[:allowed]
      true
    end
    def scope_runs(relation, context:) = relation.where(owner_digest: Digest::SHA256.hexdigest(identity(context)))
    def persist!(run, answers, context)
      raise failure if failure
      FlowIntakeRequest.create!(run_id: run.id, customer_key: identity(context))
      @persisted << [run.id, answers]
    end
    def deliver(request)
      @delivered << request.id
      :sent
    end
  end

  def build_flow
    @context = {identity: "alice", allowed: true}
    @adapter = Adapter.new
    @flow = AnnesIntake::Flow.create!(key: "intake", name: "Intake")
    @version = @flow.versions.create!(number: 1, title: "Intake")
    2.times do |i|
      form = AnnesIntake::Form.create!(key: "part_#{i}", name: "Part #{i}")
      version = form.versions.create!(number: 1, title: "Part #{i}")
      version.fields.create!(key: "name", label: "Name", required: true)
      AnnesIntake::Definitions::PublishVersion.call(version, expected_lock_version: 0)
      @version.steps.create!(key: "part_#{i}", title: "Part #{i}", position: i, form_version: version)
    end
    AnnesIntake::Flows::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
    AnnesIntake.configuration.adapters[@flow.key] = @adapter
    @run = AnnesIntake::Flows::StartRun.call(flow: @flow, context: @context, request_key: SecureRandom.uuid)
  end
end
