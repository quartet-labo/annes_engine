# AnneAudit Security and Operations

AnneAudit stores durable audit data. Host applications should decide retention,
access control, and masking before enabling broad event capture.

## Metadata Filtering

Metadata is recursively normalized before persistence. Symbol values become
strings. Keys matching configured sensitive terms are removed before storage.

Default filter terms include:

- `password`
- `token`
- `code`
- `otp`
- `cookie`
- `secret`
- `credential`

Add host-specific keys in the initializer:

```ruby
AnneAudit.configure do |config|
  config.metadata_filter_keys += %i[api_key customer_secret]
end
```

Filtering is key-based. It does not inspect arbitrary free text. Do not place
passwords, plaintext tokens, session cookies, private notes, or unreviewed
request parameters into audit metadata.

## PII and Access Control

Audit events may include account email, IP address, user agent, actor labels,
target labels, and host metadata. Treat the table as sensitive operational data.

Recommended host controls:

- expose audit screens only to trusted staff roles;
- avoid broad metadata dumps from params or model attributes;
- prefer stable IDs and short labels over full record snapshots;
- document which event sources include customer PII;
- make audit access itself subject to authentication and authorization.

## Retention

AnneAudit does not delete events automatically. Retention is host policy because
business, legal, and customer requirements vary.

Recommended host decisions:

- retention period per application or tenant;
- whether auth events and admin CRUD events have different retention periods;
- backup retention alignment;
- procedure for masking or deleting PII when legally required;
- whether deletion jobs should create their own audit event.

## Persistence Failure Semantics

Notification subscribers run inline under Rails notification semantics.

Default behavior:

```ruby
config.raise_on_persistence_error = false
```

In default mode, AnneAudit logs persistence failures and allows the originating
request or operation to continue. This keeps `anne_admin`, `annes_auth`, and host
domain code loosely coupled to audit storage.

Audit-required behavior:

```ruby
config.raise_on_persistence_error = true
```

In audit-required mode, AnneAudit re-raises persistence failures from
notification subscribers. The originating request or operation fails.

This setting does not guarantee transaction atomicity. If an event is emitted
after a domain record has already been saved, the request may fail while the
domain change remains committed. Strict flows should call `AnneAudit.record!`
inside the same transaction as the domain write, or use a future
transaction-aware integration point.

## Async Persistence

MVP subscribers persist inline. Hosts can register a custom mapper or subscriber
path that enqueues a job, but that changes failure semantics. If durable audit
storage is mandatory, test the queue outage and retry behavior explicitly.
