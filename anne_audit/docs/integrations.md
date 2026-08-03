# AnneAudit Integrations

AnneAudit integrates with notification streams through mapper registration.
Core persistence stays generic; each mapper owns one notification payload
contract.

## Mapper Contract

A mapper receives an `ActiveSupport::Notifications::Event` and returns keyword
attributes accepted by `AnneAudit.record!`.

```ruby
class HostAuditMapper
  def self.call(event)
    payload = event.payload.symbolize_keys

    {
      source: "host",
      action: payload.fetch(:action),
      result: payload[:status] || "success",
      occurred_at: Time.zone.at(event.time),
      actor: payload[:actor],
      target: payload[:target],
      metadata: payload[:metadata] || {}
    }
  end
end
```

Register the mapper:

```ruby
AnneAudit.configure do |config|
  config.notification_subscribers.register(
    "host.audit",
    mapper: HostAuditMapper
  )
end
```

## AnneAdmin

AnneAdmin emits `anne_admin.audit` notifications for standard create, update,
destroy, and custom action success or failure paths.

Register the built-in mapper:

```ruby
AnneAudit.configure do |config|
  config.notification_subscribers.register(
    "anne_admin.audit",
    mapper: AnneAudit::Mappers::AnneAdmin
  )
end
```

Current AnneAdmin payload fields are:

- `resource`
- `action`
- `record_id`
- `user_id`
- `status`

The mapper stores:

- `source`: `anne_admin`
- `action`: payload action
- `result`: payload status
- actor ID/label from `user_id`
- target type from `resource`
- target ID from `record_id`
- remaining non-reference fields in metadata

The mapper lets `AnneAudit::Event` generate `event_id`. Do not use
`event.transaction_id` as an audit event identifier; Rails reuses that value for
notifications emitted by the same instrumenter.

If a host needs richer actor or target labels, extend the emitted payload with
backward-compatible keys such as `actor_type`, `actor_label`, `target_type`, or
`target_label`.

## AnneAuth

AnneAuth emits `anne_auth.account_event` notifications for account lifecycle and
authentication events.

Register the built-in mapper:

```ruby
AnneAudit.configure do |config|
  config.notification_subscribers.register(
    "anne_auth.account_event",
    mapper: AnneAudit::Mappers::AnneAuth
  )
end
```

The mapper stores:

- `source`: `anne_auth`
- `action`: payload event
- `result`: payload status
- actor and target from account class, account ID, and account email
- IP address and user agent from payload
- session/auth/provider context in metadata

AnneAuth already filters credential-like metadata before emitting account
events. AnneAudit still applies its own metadata filter before storage.

## Host Domain Events

Host applications can emit their own notifications:

```ruby
ActiveSupport::Notifications.instrument(
  "host.audit",
  action: "reservation.cancel",
  actor: {
    type: current_account.class.name,
    id: current_account.to_param,
    label: current_account.email
  },
  target: {
    type: reservation.class.name,
    id: reservation.to_param,
    label: reservation.reservation_number
  },
  metadata: {
    reason: cancel_reason
  }
)
```

For domain flows that require transaction atomicity, prefer direct
`AnneAudit.record!` inside the domain transaction instead of relying on a
post-save notification.
