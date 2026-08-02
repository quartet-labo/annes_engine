require_relative "../../test_helper"

class AnneAudit::ContextTest < AnneAudit::TestCase
  Request = Struct.new(:request_id, :remote_ip, :user_agent, keyword_init: true)
  Actor = Struct.new(:id, :email, keyword_init: true) do
    def to_param
      id
    end
  end

  test "record uses context actor and request when omitted" do
    actor = Actor.new(id: "account-123", email: "owner@example.com")
    request = Request.new(request_id: "request-123", remote_ip: "203.0.113.10", user_agent: "Mozilla/5.0")

    event = AnneAudit.with_context(actor: actor, request: request) do
      AnneAudit.record!(source: "host", action: "customer.update")
    end

    assert_equal "account-123", event.actor_id
    assert_equal "owner@example.com", event.actor_label
    assert_equal "request-123", event.request_id
  end

  test "context is restored after the block" do
    actor = Actor.new(id: "account-123", email: "owner@example.com")

    AnneAudit.with_context(actor: actor) do
      assert_equal actor, AnneAudit::Context.current.fetch(:actor)
    end

    assert_empty AnneAudit::Context.current
  end
end
