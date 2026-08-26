require_relative "../../test_helper"

class AnnesAudit::RecorderTest < AnnesAudit::TestCase
  Request = Struct.new(:request_id, :remote_ip, :user_agent, keyword_init: true)
  Actor = Struct.new(:id, :email, keyword_init: true) do
    def to_param
      id
    end
  end
  Target = Struct.new(:id, :name, keyword_init: true) do
    def to_param
      id
    end
  end

  test "records actor target request and metadata" do
    occurred_at = Time.zone.local(2026, 8, 2, 12, 30, 0)
    actor = Actor.new(id: "account-123", email: "admin@example.com")
    target = Target.new(id: "reservation-456", name: "Reservation R-1")
    request = Request.new(request_id: "request-789", remote_ip: "203.0.113.10", user_agent: "Mozilla/5.0")

    event = AnnesAudit.record!(
      source: :host,
      action: :"reservation.cancel",
      actor: actor,
      target: target,
      request: request,
      occurred_at: occurred_at,
      result: :failure,
      metadata: { reason: :duplicate, password: "hidden" }
    )

    assert_equal "host", event.source
    assert_equal "reservation.cancel", event.action
    assert_equal "failure", event.result
    assert_equal occurred_at, event.occurred_at
    assert_equal "AnnesAudit::RecorderTest::Actor", event.actor_type
    assert_equal "account-123", event.actor_id
    assert_equal "admin@example.com", event.actor_label
    assert_equal "AnnesAudit::RecorderTest::Target", event.target_type
    assert_equal "reservation-456", event.target_id
    assert_equal "Reservation R-1", event.target_label
    assert_equal "request-789", event.request_id
    assert_equal "203.0.113.10", event.ip_address
    assert_equal "Mozilla/5.0", event.user_agent
    assert_equal({ "reason" => "duplicate" }, event.metadata)
  end

  test "records explicit hash references and nil context" do
    event = AnnesAudit.record!(
      source: "host",
      action: "bulk.import",
      actor: { type: "Account", id: "uuid-1", label: "Owner" },
      target: nil
    )

    assert_equal "Account", event.actor_type
    assert_equal "uuid-1", event.actor_id
    assert_equal "Owner", event.actor_label
    assert_nil event.target_type
  end

  test "record returns false on validation failure" do
    assert_equal false, AnnesAudit.record(source: nil, action: nil)
  end
end
