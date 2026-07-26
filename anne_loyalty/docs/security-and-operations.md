# AnneLoyalty Security and Operations

Use this checklist before enabling AnneLoyalty in a production host app.

## Token Handling

- Set `AnneLoyalty.configuration.token_digest_secret` to a stable production
  secret. Do not rely on test fallbacks.
- Store only redemption token digests. The raw token should appear only in the
  response that creates the redemption and in the customer's QR payload.
- Keep redemption token lifetimes short through each reward's `valid_minutes`.
- Rotate the token secret only with a plan to expire or reissue outstanding
  `issued` redemptions.

## Ledger Integrity

- Treat `LoyaltyLedgerEntry` as append-only. Use `AnneLoyalty.reverse!` for
  corrections instead of updating or deleting historical entries.
- Pass a stable `source` to `earn!` for every receipt, POS event, or external
  import so retries are idempotent.
- Keep database uniqueness constraints for source idempotency and token digest
  uniqueness enabled.
- Reconcile `cached_balance` against point lots and ledger totals during
  operational audits.

## Authorization Boundary

- Authenticate staff in the host app before calling staff-facing services.
- Authorize host controller actions with `anne_access` or equivalent host
  policy before allowing earning, redemption confirmation, or admin changes.
- Pass `actor` and request metadata to service calls so ledger and redemption
  records retain an audit trail.
- Do not expose engine models directly through public APIs without host-level
  ownership and tenant scoping.

## Operations

- Run point mutations against PostgreSQL. The services depend on row locks and
  transactions for concurrent earning and redemption.
- Keep host seed credentials development-only. Replace all demo passwords and
  sample accounts before production use.
- Monitor rejected token confirmations separately from application errors; high
  rates can indicate stale QR screens, repeated scans, or abuse.
- Back up loyalty tables with the host application's operational database
  backups. Ledger records are business records, not cache data.

## Current MVP Limits

- Campaign evaluation, tier/rank logic, expiration batch processing, reporting,
  POS import adapters, and offline token fallback are not implemented in
  `anne_loyalty` 0.1.0.
- The engine provides services and persistence, not customer or staff UI. Host
  applications own QR presentation, scan workflows, copy, and styling.
