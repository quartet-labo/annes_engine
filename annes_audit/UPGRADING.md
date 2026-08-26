# AnnesAudit Upgrade Guide

## 0.1.x -> 1.0.0

This is a breaking package and namespace migration.

1. Replace `gem "anne_audit"` with `gem "annes_audit", "~> 1.0"`, then run
   `bundle update annes_audit`.
2. Rename `config/initializers/anne_audit.rb` to
   `config/initializers/annes_audit.rb`, and replace `AnneAudit` with
   `AnnesAudit` in host code.
3. Run `bin/rails db:migrate`. The included migration renames
   `anne_audit_events` and all of its indexes to the `annes_audit` prefix
   without changing audit event rows.
4. Replace built-in mapper references with `AnnesAudit::Mappers::AnnesAuth`
   and `AnnesAudit::Mappers::AnnesAdmin`. The source notifications remain
   `annes_auth.account_event` and `annes_admin.audit`.

Back up the database before migrating and run the host audit integration tests.
If both old and new audit tables already exist, the migration stops rather than
risk hiding historical events; reconcile those tables explicitly first.
