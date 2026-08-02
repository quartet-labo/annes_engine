# AnneAudit

AnneAudit is a reusable Rails engine for durable audit event persistence.

The engine stores append-only events with actor, target, action, result, request
context, and filtered metadata. It can be used directly through
`AnneAudit.record!` or connected to notification streams with mapper
registration.

AnneAudit does not require AnneAdmin or AnneAuth. Host applications can register
notification mappers when they want to persist events emitted by other engines.
