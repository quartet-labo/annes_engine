require_relative "../../test_helper"

class AnnesAudit::EventTest < AnnesAudit::TestCase
  test "creates an event with generated identifiers and defaults" do
    event = AnnesAudit::Event.create!(source: "host", action: "reservation.cancel")

    assert_match(/\A[0-9a-f-]{36}\z/, event.event_id)
    assert_equal "success", event.result
    assert event.occurred_at.present?
    assert_equal({}, event.metadata)
  end

  test "requires stable audit fields" do
    event = AnnesAudit::Event.new

    assert_not event.valid?
    assert_includes event.errors[:source], "can't be blank"
    assert_includes event.errors[:action], "can't be blank"
  end

  test "is append only after create" do
    event = AnnesAudit::Event.create!(source: "host", action: "reservation.cancel")

    assert event.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(action: "reservation.update") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy! }
  end
end
