require "test_helper"

class UnattachedBlobCleanupTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  test "only aged unreferenced engine uploads are cleaned" do
    blobs = [ true, true, false ].map do |owned|
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new("content"), filename: "file.txt", metadata: { annes_inquiry: owned })
    end
    old, recent, foreign = blobs
    old.update!(created_at: 3.days.ago)
    foreign.update!(created_at: 3.days.ago)
    AnnesInquiry::UnattachedBlobCleanup.call
    assert_not ActiveStorage::Blob.exists?(old.id)
    assert_not old.service.exist?(old.key)
    assert ActiveStorage::Blob.exists?(recent.id)
    assert ActiveStorage::Blob.exists?(foreign.id)
    assert_raises(ArgumentError) { AnnesInquiry::UnattachedBlobCleanup.call(before: Time.current) }
  ensure
    blobs&.each { |blob| blob.reload.purge if ActiveStorage::Blob.exists?(blob.id) }
  end

  test "rollback before commit preserves both blob and storage object" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("content"), filename: "file.txt", metadata: { annes_inquiry: true })
    blob.update!(created_at: 3.days.ago)
    callback = proc do
      if id == blob.id
        self.class.connection.current_transaction.before_commit { raise "Commit failed" }
      end
    end
    ActiveStorage::Blob.set_callback(:destroy, :after, callback)
    error = assert_raises(RuntimeError) { AnnesInquiry::UnattachedBlobCleanup.call }
    assert_equal "Commit failed", error.message
    assert ActiveStorage::Blob.exists?(blob.id)
    assert blob.service.exist?(blob.key)
    assert_not AnnesInquiry::BlobDeletion.exists?(key: blob.key)
  ensure
    ActiveStorage::Blob.skip_callback(:destroy, :after, callback) if callback
    blob.reload.purge if blob && ActiveStorage::Blob.exists?(blob.id)
  end

  test "storage deletion runs after the database deletion commits" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("content"), filename: "file.txt", metadata: { annes_inquiry: true })
    blob.update!(created_at: 3.days.ago)
    service = blob.service
    original = service.method(:delete)
    observations = []
    service.define_singleton_method(:delete) do |key|
      observations << [ActiveStorage::Blob.connection.transaction_open?, ActiveStorage::Blob.exists?(blob.id)] if key == blob.key
      original.call(key)
    end
    AnnesInquiry::UnattachedBlobCleanup.call
    assert_equal [[false, false]], observations
  ensure
    service.singleton_class.remove_method(:delete) if original
    blob.reload.purge if blob && ActiveStorage::Blob.exists?(blob.id)
  end


  test "storage failure leaves a durable deletion request for the next run" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("content"), filename: "file.txt", metadata: { annes_inquiry: true })
    blob.update!(created_at: 3.days.ago)
    service = blob.service
    service.define_singleton_method(:delete) { |key| raise IOError, "Storage unavailable" }
    assert_raises(IOError) { AnnesInquiry::UnattachedBlobCleanup.call }
    assert_not ActiveStorage::Blob.exists?(blob.id)
    assert service.exist?(blob.key)
    assert AnnesInquiry::BlobDeletion.exists?(key: blob.key)
    service.singleton_class.remove_method(:delete)
    AnnesInquiry::UnattachedBlobCleanup.call
    assert_not service.exist?(blob.key)
    assert_not AnnesInquiry::BlobDeletion.exists?(key: blob.key)
  ensure
    service.singleton_class.remove_method(:delete) if service&.singleton_methods(false)&.include?(:delete)
    AnnesInquiry::BlobDeletion.where(key: blob.key).each(&:purge!) if blob
    blob.reload.purge if blob && ActiveStorage::Blob.exists?(blob.id)
  end

  test "recovers a committed deletion request after an interrupted cleanup" do
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("content"), filename: "file.txt", metadata: { annes_inquiry: true })
    blob.with_lock do
      AnnesInquiry::BlobDeletion.create!(key: blob.key, service_name: blob.service_name, image: false)
      blob.destroy!
    end
    assert blob.service.exist?(blob.key)
    AnnesInquiry::UnattachedBlobCleanup.call
    assert_not blob.service.exist?(blob.key)
    assert_not AnnesInquiry::BlobDeletion.exists?(key: blob.key)
  ensure
    AnnesInquiry::BlobDeletion.where(key: blob.key).each(&:purge!) if blob
    blob.reload.purge if blob && ActiveStorage::Blob.exists?(blob.id)
  end

end
