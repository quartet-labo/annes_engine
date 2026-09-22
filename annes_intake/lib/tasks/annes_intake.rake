namespace :annes_intake do
  desc "Dispatch pending notifications and mark interrupted processing as unknown"
  task recover_notifications: :environment do
    AnnesIntake::NotificationDispatcher.recover!
  end

  desc "List aged unreferenced Engine uploads; set EXECUTE=true to purge"
  task cleanup_uploads: :environment do
    before = ENV["BEFORE"].present? ? Time.iso8601(ENV.fetch("BEFORE")) : 1.day.ago
    if ENV["EXECUTE"] == "true"
      AnnesIntake::UnattachedBlobCleanup.call(before: before)
    else
      AnnesIntake::UnattachedBlobCleanup.candidates(before: before).each { |blob| puts "#{blob.id}\t#{blob.created_at.utc.iso8601}\t#{blob.byte_size}" }
    end
  end

end

namespace :annes_intake do
  desc "Recover pending flow notifications (unknown delivery is never retried automatically)"
  task recover_flow_notifications: :environment do
    AnnesIntake::Flows::NotificationDispatcher.recover!
  end
  desc "List expired/cancelled flow drafts; EXECUTE=true removes only draft references"
  task cleanup_drafts: :environment do
    if ENV["EXECUTE"] == "true"
      AnnesIntake::Flows::DraftCleanup.call
    else
      AnnesIntake::Flows::DraftCleanup.candidates.find_each { |run| puts "#{run.id} #{run.status} #{run.expires_at}" }
    end
  end
end
