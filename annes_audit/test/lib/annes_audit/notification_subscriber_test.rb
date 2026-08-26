require "stringio"
require "logger"
require_relative "../../test_helper"

class AnnesAudit::NotificationSubscriberTest < AnnesAudit::TestCase
  Mapper = ->(_event) { { source: "test", action: "created" } }
  FailingRecorder = Class.new do
    def self.record!(**)
      raise ActiveRecord::RecordInvalid
    end
  end

  test "logs persistence failures and continues by default" do
    output = StringIO.new
    logger = Logger.new(output)
    subscriber = AnnesAudit::NotificationSubscriber.new(mapper: Mapper, recorder: FailingRecorder, logger: logger)
    event = notification_event

    assert_nothing_raised { subscriber.call(event) }
    assert_includes output.string, "AnnesAudit failed to persist audit event: ActiveRecord::RecordInvalid"
  end

  test "ignores nil mapper result" do
    subscriber = AnnesAudit::NotificationSubscriber.new(mapper: ->(_event) {})

    assert_no_difference -> { AnnesAudit::Event.count } do
      subscriber.call(notification_event)
    end
  end

  test "raises persistence failures when configured as audit required" do
    AnnesAudit.configure do |config|
      config.raise_on_persistence_error = true
    end

    subscriber = AnnesAudit::NotificationSubscriber.new(mapper: Mapper, recorder: FailingRecorder)

    assert_raises(ActiveRecord::RecordInvalid) { subscriber.call(notification_event) }
  end

  private
    def notification_event
      captured = nil
      ActiveSupport::Notifications.subscribed(->(*args) { captured = ActiveSupport::Notifications::Event.new(*args) }, "audit.test") do
        ActiveSupport::Notifications.instrument("audit.test")
      end
      captured
    end
end
