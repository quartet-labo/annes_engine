# AnneAccess Security Checklist

Use this checklist before enabling a permission matrix in production or adding a
new protected resource.

## Principal

- [ ] The principal is authenticated before authorization runs.
- [ ] The principal is persisted and has a stable ID.
- [ ] AnneAdmin, host controllers, jobs, and services resolve the same principal type.
- [ ] A configured `principal_resolver` returns nil rather than falling back when no authorization principal exists.
- [ ] Class renames include a migration for polymorphic `principal_type` values.

## Roles and Permissions

- [ ] Nil principals and principals without assignments are denied.
- [ ] Resource/action names match controller and AnneAdmin names after normalization.
- [ ] `manage` is used only for the standard action set.
- [ ] Every custom action has an explicit permission.
- [ ] `default_role_key` contains only permissions safe for every authenticated principal.
- [ ] `super_admin_role_keys` is empty or each bypass is explicitly approved and audited.
- [ ] Seed changes do not silently delete production permissions or assignments.
- [ ] Existing principals were backfilled and count-checked during adoption.

## Custom Rules

- [ ] The rule preserves `allowed == false` unless a separately reviewed exception is intended.
- [ ] Nil records are handled for collection actions.
- [ ] Queries use indexed keys and do not introduce list N+1 behavior.
- [ ] Exceptions propagate and are monitored instead of being converted to allow.

## Record Visibility

- [ ] Collection queries apply tenant/ownership scopes before search, sort, pagination, or export.
- [ ] Member records are loaded through the same scope.
- [ ] Association selectors, dashboards, background jobs, and custom actions use equivalent scopes.
- [ ] Tests include two tenants/owners and verify cross-boundary denial.

## Responses and Monitoring

- [ ] HTML and API denial responses are intentional and tested.
- [ ] Logs contain principal ID, normalized action, and resource when appropriate, but no sensitive record data.
- [ ] Permission and super-admin changes are auditable.
- [ ] Authorization failures are monitored separately from application errors.
