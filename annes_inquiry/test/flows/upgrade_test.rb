require "test_helper"

class FlowUpgradeTest < ActiveSupport::TestCase
  test "additive flow migrations preserve an existing standalone receipt" do
    connection = AnnesInquiry::ApplicationRecord.connection
    schema = "inquiry_upgrade_#{SecureRandom.hex(6)}"
    original_path = connection.schema_search_path
    verbosity = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    connection.execute("CREATE SCHEMA #{schema}")
    connection.schema_search_path = schema
    migrations = Dir[AnnesInquiry::Engine.root.join("db/migrate/*.rb")].sort
    # Frozen migration sources from 0.1.0, independent of future runtime edits.
    Dir[AnnesInquiry::Engine.root.join("test/fixtures/legacy_migrations/*.rb")].sort.each { |path| migrate(path) }
    migrate(AnnesInquiry::Engine.root.join("test/dummy/db/migrate/20260612053000_create_active_storage_tables.rb").to_s)
    now = connection.quote(Time.current)
    connection.execute("INSERT INTO annes_inquiry_forms (id, key, name, created_at, updated_at) VALUES (1, 'legacy', 'Legacy', #{now}, #{now})")
    connection.execute("INSERT INTO annes_inquiry_form_versions (id, form_id, number, title, status, created_at, updated_at) VALUES (1, 1, 1, 'Legacy', 'published', #{now}, #{now})")
    receipt = SecureRandom.uuid
    connection.execute("INSERT INTO annes_inquiry_submissions (form_version_id, receipt_id, request_key, payload_digest, received_at, created_at, updated_at) VALUES (1, '#{receipt}', '#{SecureRandom.uuid}', '#{'a' * 64}', #{now}, #{now}, #{now})")
    submission_id = connection.select_value("SELECT id FROM annes_inquiry_submissions")
    connection.execute("INSERT INTO annes_inquiry_fields (id, form_version_id, key, label, value_type, widget, created_at, updated_at) VALUES (1, 1, 'name', 'Name', 'text', 'text', #{now}, #{now}), (2, 1, 'document', 'Document', 'attachment', 'file', #{now}, #{now})")
    connection.execute("INSERT INTO annes_inquiry_answers (id, submission_id, field_id, form_version_id, value_type, text_value, created_at, updated_at) VALUES (1, #{submission_id}, 1, 1, 'text', 'Original answer', #{now}, #{now}), (2, #{submission_id}, 2, 1, 'attachment', NULL, #{now}, #{now})")
    connection.execute("INSERT INTO annes_inquiry_answer_attachments (id, answer_id, field_id, value_type, position, created_at, updated_at) VALUES (1, 2, 2, 'attachment', 0, #{now}, #{now})")
    connection.execute("INSERT INTO annes_inquiry_notification_requests (submission_id, kind, status, attempts, created_at, updated_at) VALUES (#{submission_id}, 'received', 'unknown', 1, #{now}, #{now})")
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("Original document"), filename: "original.txt", content_type: "text/plain")
    connection.execute("INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at) VALUES ('file', 'AnnesInquiry::AnswerAttachment', 1, #{blob.id}, #{now})")
    migrations.drop(5).take(2).each { |path| migrate(path) }
    connection.execute("INSERT INTO annes_inquiry_flows (key, name, created_at, updated_at) VALUES ('linear', 'Linear', #{now}, #{now})")
    flow = AnnesInquiry::Flow.find_by!(key: "linear")
    version = flow.versions.create!(number: 1, title: "Linear")
    step = version.steps.create!(key: "contact", title: "Contact", position: 0, form_version_id: 1)
    run = AnnesInquiry::FlowRun.create!(flow_version: version, owner_digest: "owner", context_digest: "context", start_key: SecureRandom.uuid, expires_at: 1.day.from_now)
    item = run.step_runs.create!(flow_step: step, flow_version_id: version.id, form_version_id: 1)
    item.draft_answers.create!(field_id: 1, form_version_id: 1, raw_value: "Saved before branching")
    migrate(migrations.fetch(7))
    target = version.steps.create!(key: "branch", title: "Branch", position: 1, form_version_id: 1)
    mapping = target.value_mappings.create!(source_step: step, source_field_id: 1, target_field_id: 1)
    connection.execute("INSERT INTO annes_inquiry_fields (id, form_version_id, key, label, value_type, widget, position, created_at, updated_at) VALUES (3, 1, 'flag', 'Flag', 'boolean', 'checkbox', 2, #{now}, #{now})")
    condition = target.condition_groups.create!.conditions.create!(source_step: step, field_id: 3, operator: "eq", expected_value: "true")
    migrations.drop(8).each { |path| migrate(path) }
    AnnesInquiry::ApplicationRecord.descendants.each(&:reset_column_information)
    assert_equal mapping.id, target.value_mappings.sole.id
    assert_equal "true", condition.reload.expected_value
    assert_nil flow.reload.follow_up_request_id
    assert_equal 0, AnnesInquiry::FollowUpRequest.count
    assert_equal [item.id], AnnesInquiry::Flows::RouteEvaluator.call(run).map(&:id)
    assert_equal "Saved before branching", AnnesInquiry::Flows::RouteEvaluator.raw_values(item).fetch("name")
    assert_equal receipt, connection.select_value("SELECT receipt_id FROM annes_inquiry_submissions")
    assert_equal 1, connection.select_value("SELECT count(*) FROM annes_inquiry_flow_runs")
    reader = AnnesInquiry::AnswerReader.new(AnnesInquiry::Submission.find(submission_id))
    assert_equal "Original answer", reader["name"]
    assert_equal "Original document", reader["document"].sole.file.download
    assert_equal "unknown", AnnesInquiry::NotificationRequest.find_by!(submission_id: submission_id).status
  ensure
    blob&.delete
    connection.schema_search_path = original_path
    connection.execute("DROP SCHEMA IF EXISTS #{schema} CASCADE") if schema
    connection.schema_cache.clear!
    AnnesInquiry::ApplicationRecord.descendants.each(&:reset_column_information)
    ActiveRecord::Migration.verbose = verbosity
  end

  private
    def migrate(path)
      require path
      File.basename(path, ".rb").sub(/\A\d+_/, "").camelize.constantize.new.migrate(:up)
    end
end
