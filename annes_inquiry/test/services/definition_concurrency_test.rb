require "test_helper"
require "timeout"

class DefinitionConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @form = AnnesInquiry::Form.create!(key: "concurrent_#{SecureRandom.hex(4)}", name: "Concurrent")
    @version = @form.versions.create!(number: 1, title: "Draft")
    @version.fields.create!(key: "name", label: "Name")
    AnnesInquiry::Definitions::PublishVersion
  end

  teardown do
    ids = @form.versions.select(:id)
    AnnesInquiry::Field.where(form_version_id: ids).delete_all
    AnnesInquiry::FormVersion.where(form_id: @form.id).delete_all
    @form.delete
  end

  test "concurrent publication has one winner" do
    ready, start, results = Queue.new, Queue.new, Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          version = AnnesInquiry::FormVersion.find(@version.id)
          ready << true
          start.pop
          begin
            AnnesInquiry::Definitions::PublishVersion.call(version, expected_lock_version: 0)
            results << :published
          rescue AnnesInquiry::Definitions::Error, ActiveRecord::StaleObjectError
            results << :rejected
          end
        end
      end
    end
    Timeout.timeout(10) do
      2.times { ready.pop }
      2.times { start << true }
      threads.each(&:value)
    end
    assert_equal %i[published rejected], 2.times.map { results.pop }.sort
    assert_equal 1, @form.versions.published.count
  ensure
    threads&.each { |thread| thread.kill if thread.alive? }
  end

  test "publication cannot overwrite an edit under the same form lock" do
    entered, release = Queue.new, Queue.new
    editor = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        AnnesInquiry::Definitions::DraftEditor.call(@version, expected_lock_version: 0) do |draft|
          entered << true
          release.pop
          draft.fields.first.update!(label: "Changed")
        end
      end
    end
    Timeout.timeout(10) { entered.pop }
    publisher = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          AnnesInquiry::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
        rescue ActiveRecord::StaleObjectError
          :stale
        end
      end
    end
    release << true
    Timeout.timeout(10) do
      editor.value
      assert_equal :stale, publisher.value
    end
    assert @version.reload.draft?
    assert_equal "Changed", @version.fields.first.label
  ensure
    [ editor, publisher ].compact.each { |thread| thread.kill if thread.alive? }
  end
end
