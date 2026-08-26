# AnnesAudit

AnnesAudit is a reusable Rails engine for durable audit event persistence.

The engine stores append-only events with actor, target, action, result, request
context, and filtered metadata. It can be used directly through
`AnnesAudit.record!` or connected to notification streams with mapper
registration.

AnnesAudit does not require AnnesAdmin or AnnesAuth. Host applications can register
notification mappers when they want to persist events emitted by other engines.

## Responsibilities

AnnesAudit owns:

- durable audit event persistence;
- actor and target reference snapshots;
- request context capture;
- metadata filtering;
- `AnnesAudit.record!` and `AnnesAudit.record`;
- generic notification mapper registration;
- built-in mappers for known Anne Engine notification contracts.

AnnesAudit does not own authentication, authorization, admin CRUD screens, SIEM
forwarding, tamper-proof storage, or analytics dashboards.

## Installation

Add the gem to the host application.

```ruby
gem "annes_audit", "~> 1.0"
```

Install the initializer and migration.

```sh
bin/rails generate annes_audit:install
bin/rails db:migrate
```

## Data Model

`annes_audit_events` stores append-only event rows. Actor and target IDs are
strings and are not foreign keys so audit rows can survive deleted records and
support bigint, UUID, and string primary keys.

Core fields:

- `event_id`
- `source`
- `action`
- `result`
- `occurred_at`
- `actor_type`, `actor_id`, `actor_label`
- `target_type`, `target_id`, `target_label`
- `request_id`, `ip_address`, `user_agent`
- `metadata`

## Recording Events

Use `record!` when audit persistence must raise on validation or database
errors.

```ruby
AnnesAudit.record!(
  source: "host",
  action: "reservation.cancel",
  actor: current_account,
  target: reservation,
  request: request,
  result: :success,
  metadata: {
    reason: params[:reason]
  }
)
```

Use `record` when the caller wants a falsey result instead of an exception for
validation or database persistence failures.

```ruby
event = AnnesAudit.record(source: "host", action: "customer.update")
```

For service objects that do not receive the request directly, wrap the call with
context:

```ruby
AnnesAudit.with_context(actor: current_account, request: request) do
  CustomerUpdater.call(customer, params)
end
```

Any nested `AnnesAudit.record!` call uses the context actor and request unless
explicit values are passed.

## Notification Mappers

AnnesAudit can subscribe to any `ActiveSupport::Notifications` event through a
mapper object that responds to `call(event)` and returns attributes for
`AnnesAudit.record!`.

```ruby
AnnesAudit.configure do |config|
  config.notification_subscribers.register(
    "annes_admin.audit",
    mapper: AnnesAudit::Mappers::AnnesAdmin
  )

  config.notification_subscribers.register(
    "annes_auth.account_event",
    mapper: AnnesAudit::Mappers::AnnesAuth
  )
end
```

The default failure behavior is loose coupling. Subscriber persistence errors
are logged and the originating request continues.

```ruby
AnnesAudit.configure do |config|
  config.raise_on_persistence_error = false
end
```

Set `raise_on_persistence_error` to `true` when a host needs audit persistence
failures to fail the originating request.

## AnnesAdmin Read-only Resource Example

AnnesAudit does not require AnnesAdmin, and it does not ship admin screens. Hosts
that already use AnnesAdmin can register a read-only resource:

```ruby
AnnesAdmin.resource :audit_events, model: "AnnesAudit::Event", actions: %i[index show] do
  fields :occurred_at, :source, :action, :result, :actor_label, :target_label
  searchable_by :source, :action, :result, :actor_label, :target_label
  sortable_by :occurred_at, :source, :action, :result
end
```

## Operations

Read [security and operations](docs/security-and-operations.md) before writing
PII-heavy metadata to durable storage or enabling audit-required failure mode.

Read [integrations](docs/integrations.md) for built-in mapper details and custom
mapper examples.
