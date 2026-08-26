# Changelog

## Unreleased

## 1.0.0

- Rename the published gem from `anne_audit` to `annes_audit` and the public
  Ruby namespace from `AnneAudit` to `AnnesAudit`.
- Rename audit events, indexes, initializer, generator, and mapper classes to
  the `annes_audit` / `AnnesAudit` contract.
- Add a reversible migration that preserves existing `anne_audit_events` rows
  while renaming the table and its indexes.

## 0.1.0

- Add the initial AnneAudit engine scaffold.
- Add append-only audit event persistence with `AnneAudit.record!`,
  `AnneAudit.record`, context propagation, metadata filtering, and notification
  mapper registration.
