# AnneAdmin Queries, Actions, and Audit Events

## Query Parameters

The resource index accepts:

| Parameter | Purpose | Validation |
| --- | --- | --- |
| `q` | Keyword search | Applied only to configured searchable string/text columns; SQL wildcard characters are escaped |
| `sort` | Sort column | Must be in the resource sort allowlist and a real model column |
| `direction` | Sort direction | `asc` or `desc`; invalid values become `asc` |
| `scope` | Named resource scope | Unknown names leave the relation unchanged |
| `page` | One-based page | Non-positive/invalid values become 1 |
| `per_page` | Page size | Non-positive/invalid values use the configured default and large values are capped |

Configuration defaults are 25 rows per page and a maximum of 100:

```ruby
AnneAdmin.configure do |config|
  config.default_per_page = 25
  config.max_per_page = 100
end
```

Pagination uses `limit` and `offset`. Very high page numbers can still produce
expensive offsets; host controllers can replace the query/collection behavior
when keyset pagination is required.

## Query Order

AnneAdmin applies operations in this order:

1. resource base relation or host `resource_scope`;
2. named scope;
3. keyword search;
4. allowlisted sort;
5. limit and offset.

`total_count` is computed from the filtered relation before pagination. Apply
tenant constraints in `resource_scope`, not after `@query.records`, so both
records and counts respect the boundary.

Use `includes` in the resource DSL for associations read by display callables:

```ruby
includes :customer, :owner
```

Inspect query logs when a display field calls host methods that may load nested
associations.

## Custom Action Requests

Member and collection actions have separate routes:

```text
/:resource_name/:id/actions/:action_name
/:resource_name/actions/:action_name
```

Registered methods may be POST, PATCH, PUT, or DELETE. The controller returns
404 for an unknown action or wrong member/collection scope, and 405 when the
request method does not match the action configuration.

Authorization runs with the custom action name. A member action receives the
loaded record; a collection action receives `record: nil`.

The action block can render or redirect through its controller. Otherwise the
Engine redirects to the member show page or resource index after success. The
default show view renders member-action buttons and confirmation text. The
default index does not render collection-action buttons, so add a host view when
users need to invoke one from the UI.

## Audit Notifications

AnneAdmin instruments `anne_admin.audit` through
`ActiveSupport::Notifications`.

| Payload key | Value |
| --- | --- |
| `resource` | Registered resource name |
| `action` | Standard or custom action name as a string |
| `record_id` | `record.to_param`, or nil for collection actions |
| `user_id` | Current user ID, email fallback, string fallback, or nil |
| `status` | `success` or `failure` |

Subscribe in the host and delegate durable storage:

```ruby
ActiveSupport::Notifications.subscribe("anne_admin.audit") do |event|
  AdminAuditEvent.create!(
    event_id: event.transaction_id,
    occurred_at: Time.zone.at(event.time),
    duration_ms: event.duration,
    **event.payload.symbolize_keys
  )
end
```

Keep the subscriber fast or enqueue a job. Decide how audit persistence errors
should affect the admin request; silently losing required audit records is not a
safe default.

## Notification Coverage

- successful create, update, and destroy emit `success`;
- validation failure during create or update emits `failure`;
- a successful member or collection custom action emits `success`;
- an exception from destroy or a custom action propagates before a failure event
  is emitted by the current implementation;
- read-only index/show operations do not emit audit events.

If the host requires durable failure audits for exceptions, capture them in a
host controller/service or error-monitoring integration. Do not document the
notification stream as a complete security audit ledger without covering those
gaps.

## Testing Actions and Audits

Cover the expected HTTP method and scope, authorization denial, service error,
redirect, and payload. For mutating actions, assert both the domain result and
the emitted notification rather than relying on the success message alone.
