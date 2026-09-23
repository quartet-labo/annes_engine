require "test_helper"
require "timeout"

class UploadRollbackTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @form = AnnesInquiry::Form.create!(key: "upload_#{SecureRandom.hex(6)}", name: "Upload")
    @version = @form.versions.create!(number: 1, title: "Upload")
    field = @version.fields.create!(key: "files", label: "Files", value_type: "attachment", widget: "file", max_files: 1, max_file_bytes: 1024)
    field.file_types.create!(extension: ".txt", content_type: "text/plain")
    AnnesInquiry::Definitions::PublishVersion.call(@version, expected_lock_version: 0)
    @file = Tempfile.new("inquiry-rollback")
    @file.write("original content")
    @file.rewind
    @upload = ActionDispatch::Http::UploadedFile.new(tempfile: @file, filename: "file.txt")
  end

  teardown do
    @file.close!
    submissions = AnnesInquiry::Submission.where(form_version_id: @version.id)
    answers = AnnesInquiry::Answer.where(submission_id: submissions.select(:id))
    AnnesInquiry::AnswerAttachment.where(answer_id: answers.select(:id)).find_each(&:destroy!)
    answers.delete_all
    submissions.delete_all
    ActiveStorage::Blob.find_by(key: @blob_key)&.purge
    fields = AnnesInquiry::Field.where(form_version_id: @version.id)
    AnnesInquiry::FieldFileType.where(field_id: fields.select(:id)).delete_all
    fields.delete_all
    AnnesInquiry::FormVersion.where(id: @version.id).delete_all
    AnnesInquiry::Form.where(id: @form.id).delete_all
  end

  test "outer rollback removes a newly uploaded file and its blob row" do
    rollback_submission
    assert_not ActiveStorage::Blob.exists?(key: @blob_key)
    assert_not ActiveStorage::Blob.service.exist?(@blob_key)
  end

  test "storage deletion failure leaves a durable unreferenced cleanup candidate" do
    service = ActiveStorage::Blob.service
    original_delete = service.method(:delete)
    begin
      service.define_singleton_method(:delete) { |key| raise IOError, "storage temporarily unavailable" }
      rollback_submission
    ensure
      service.define_singleton_method(:delete, original_delete)
    end
    candidate = ActiveStorage::Blob.find_by!(key: @blob_key)
    assert candidate.metadata["annes_inquiry"]
    assert_not candidate.attachments.exists?
    candidate.update!(created_at: 3.days.ago)
    AnnesInquiry::UnattachedBlobCleanup.call
    assert_not ActiveStorage::Blob.exists?(key: @blob_key)
    assert_not ActiveStorage::Blob.service.exist?(@blob_key)
  end

  test "replay compares upload contents without duplicating blobs" do
    token = AnnesInquiry::SubmissionToken.issue(@version, identity: "sender")
    options = { form: @form, token: token, identity: "sender", raw_values: { "files" => [ @upload ] } }
    first = AnnesInquiry::SubmissionService.call(**options)
    assert first.success?
    attachment = first.submission.answers.first.attachments.first
    @blob_key = attachment.file.blob.key
    assert_no_difference([ "AnnesInquiry::Submission.count", "ActiveStorage::Blob.count" ]) do
      assert_equal first.submission.id, AnnesInquiry::SubmissionService.call(**options).submission.id
      @file.rewind
      @file.truncate(0)
      @file.write("changed content")
      @file.rewind
      assert_equal 409, AnnesInquiry::SubmissionService.call(**options).status
    end
    assert_equal "original content", attachment.file.download
  end

  test "concurrent replay uploads only the winning attachment" do
    second_file = Tempfile.new("inquiry-concurrent")
    second_file.write("original content")
    second_file.rewind
    second_upload = ActionDispatch::Http::UploadedFile.new(tempfile: second_file, filename: "file.txt")
    token = AnnesInquiry::SubmissionToken.issue(@version, identity: "sender")
    entered, release, uploads = Queue.new, Queue.new, Queue.new
    adapter = Object.new
    adapter.define_singleton_method(:validate_input) { |_values, _context| entered << true; release.pop; {} }
    original_upload = AnnesInquiry::AnswerWriter.method(:upload_files)
    options = { form: @form, token: token, identity: "sender", adapter: adapter }

    AnnesInquiry::AnswerWriter.define_singleton_method(:upload_files) do |values|
      uploads << true
      original_upload.call(values)
    end
    begin
      initial_blob_count = ActiveStorage::Blob.uncached { ActiveStorage::Blob.count }
      threads = [ @upload, second_upload ].map do |upload|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            AnnesInquiry::SubmissionService.call(**options, raw_values: { "files" => [ upload ] })
          end
        end
      end
      2.times { Timeout.timeout(10) { entered.pop } }
      2.times { release << true }
      results = threads.map { |thread| Timeout.timeout(10) { thread.value } }
      assert results.all?(&:success?)
      assert_equal 1, results.map { |result| result.submission.id }.uniq.size
      assert_equal initial_blob_count + 1, ActiveStorage::Blob.uncached { ActiveStorage::Blob.count }
    ensure
      threads&.each { |thread| thread.kill if thread.alive? }
      AnnesInquiry::AnswerWriter.define_singleton_method(:upload_files, original_upload)
    end

    assert_equal 1, uploads.size
    attachment = AnnesInquiry::Submission.where(form_version: @version).sole.answers.first.attachments.first
    @blob_key = attachment.file.blob.key
  ensure
    second_file&.close!
  end

  private
    def rollback_submission
      AnnesInquiry::ApplicationRecord.transaction do
        token = AnnesInquiry::SubmissionToken.issue(@version, identity: "sender")
        result = AnnesInquiry::SubmissionService.call(form: @form, token: token, identity: "sender", raw_values: { "files" => [ @upload ] })
        assert result.success?, result.input.errors.full_messages.inspect
        @blob_key = result.submission.answers.first.attachments.first.file.blob.key
        assert ActiveStorage::Blob.service.exist?(@blob_key)
        raise ActiveRecord::Rollback
      end
      assert_equal 0, AnnesInquiry::Submission.where(form_version_id: @version.id).count
    end
end
