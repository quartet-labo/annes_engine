# AnnesAdmin Security Checklist

## Access Hooks

- [ ] `authenticate_with` is configured and denial performs a redirect, render, or head response.
- [ ] `current_user` returns the intended authenticated principal.
- [ ] `authorize_with` is explicitly configured; omission allows authenticated requests.
- [ ] Standard and custom actions have tested denial paths.
- [ ] Authentication and authorization exceptions are not swallowed as success.
- [ ] The default dashboard/navigation exposing every registered resource name is acceptable, or a host-filtered view replaces it.

## Resources and Fields

- [ ] Only intended host models are registered.
- [ ] Sensitive columns are not displayed.
- [ ] `permitted_attributes` is explicit for writable resources.
- [ ] IDs, timestamps, role keys, ownership keys, and calculated fields are readonly unless intentionally editable.
- [ ] Search and sort fields are allowlisted and backed by suitable indexes where needed.
- [ ] Association collections cannot expose cross-tenant records.

## Record Visibility

- [ ] `resource_scope` applies tenant/ownership constraints before count, search, sort, and pagination.
- [ ] Member lookup uses the same constrained relation.
- [ ] Dashboard data, exports, selectors, and collection custom actions apply equivalent scopes.
- [ ] Tests use at least two tenants/owners.

## Custom Actions

- [ ] The HTTP method matches the operation's side effects.
- [ ] Destructive actions use confirmation where appropriate.
- [ ] Business logic delegates to a tested host service with clear transactions and error handling.
- [ ] AnnesAccess integrations create explicit custom-action permissions.
- [ ] Collection actions do not operate on an unscoped model relation.
- [ ] CSRF protection remains enabled for browser actions.

## Audit and Operations

- [ ] The `annes_admin.audit` subscriber stores required fields without secrets or sensitive record data.
- [ ] The host accounts for exceptions that do not emit a failure notification.
- [ ] Audit storage failures are monitored and have an intentional request policy.
- [ ] Pagination limits are appropriate for the host workload.
- [ ] Query logs have been checked for N+1 behavior on association fields.
- [ ] Resource loading errors fail deployment/startup visibly.
