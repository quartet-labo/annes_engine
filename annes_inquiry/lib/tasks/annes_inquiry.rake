namespace :annes_inquiry do
  desc "Dispatch pending notifications and mark interrupted processing as unknown"
  task recover_notifications: :environment do
    AnnesInquiry::NotificationDispatcher.recover!
  end

  desc "List aged unreferenced Engine uploads; set EXECUTE=true to purge"
  task cleanup_uploads: :environment do
    before = ENV["BEFORE"].present? ? Time.iso8601(ENV.fetch("BEFORE")) : 1.day.ago
    if ENV["EXECUTE"] == "true"
      AnnesInquiry::UnattachedBlobCleanup.call(before: before)
    else
      AnnesInquiry::UnattachedBlobCleanup.candidates(before: before).each { |blob| puts "#{blob.id}\t#{blob.created_at.utc.iso8601}\t#{blob.byte_size}" }
    end
  end
  desc "List inquiry receipts beyond the configured retention period without deleting them"
  task retention_candidates: :environment do
    days = AnnesInquiry.configuration.retention_days
    abort "Set a positive retention_days in the host configuration first" unless days.is_a?(Integer) && days.positive?
    AnnesInquiry::Submission.where("received_at < ?", days.days.ago).order(:id).find_each do |submission|
      puts "#{submission.id}\t#{submission.received_at.utc.iso8601}"
    end
  end
end
