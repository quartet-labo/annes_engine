# AnneAccess Upgrade Guide

This guide lists manual steps required when upgrading AnneAccess in a host
application. Use `CHANGELOG.md` for the full list of code changes; use this file
for actions the host app must perform.

## General Upgrade Checklist

1. Update the host app `Gemfile` version or path.
2. Run `bundle update anne_access`.
3. Copy any new AnneAccess migrations into the host app.
   - Preferred: run `bin/rails generate anne_access:install` and review
     generated / skipped files.
   - Alternative: copy only the missing migration files from
     `anne_access/db/migrate`.
4. Run `bin/rails db:migrate`.
5. Review `config/initializers/anne_access.rb`.
6. Run authorization and admin-screen tests.

If a release has no manual steps, no action is needed beyond updating the gem
and running tests.

## Unreleased

This release changes documentation and the generated seed example. No database
migrations or runtime behavior changes are required for existing host apps.

Host apps that rerun `bin/rails generate anne_access:install` should review the
generated `db/seeds/anne_access.rb`. The template now uses a `role_permissions`
matrix shape so role names, resources, and actions can be adjusted in one
place. Existing seed files do not need to be rewritten unless the host app wants
to adopt that shape.

Tenant, owner, assignee, customer, and membership record scopes remain host-app
responsibilities. Keep those rules in controller lookups, query objects, model
scopes, or services rather than moving them into AnneAccess runtime code.

## 0.1.1 -> 0.1.2

This release expands documentation only. No host-app code or database changes
are required.

## 0.1.0 -> 0.1.1

### Who Is Affected

Host apps that need controller authorization to use a different principal than
the default `current_account` / `current_user` lookup.

### Required Steps

No manual host-app changes are required unless the app needs custom controller
principal resolution.

To authorize against a different principal, update
`config/initializers/anne_access.rb`:

```ruby
AnneAccess.configure do |config|
  config.principal_resolver = ->(controller) { controller.send(:current_user) }
end
```

### Verification

- Existing authorization checks still use the expected principal.
- Apps configuring `principal_resolver` deny access when the resolver returns
  `nil`.

## Initial Adoption

### Who Is Affected

Host apps moving admin or business authorization from ad hoc checks such as
`account.role == "admin"` to AnneAccess RBAC.

### Required Steps

1. Add the gem:

   ```ruby
   gem "anne_access", "~> 0.1.0"
   ```

2. Install files and migrate:

   ```sh
   bin/rails generate anne_access:install
   bin/rails db:migrate
   ```

3. Configure principals:

   ```ruby
   AnneAccess.configure do |config|
     config.principal_class_names = ["Account"]
     config.super_admin_role_keys = []
     config.default_role_key = nil
   end
   ```

4. Create role / permission / assignment data for the host app.

   For admin resources, the usual minimum is:

   - `admin` role with `manage` permissions for each admin resource.
   - `viewer` role with `read` permissions if the app supports read-only users.

5. Backfill existing users into `AnneAccess::Assignment`.

   If the host app already has `accounts.role`, create a host migration or rake
   task that maps existing values to AnneAccess roles. Do not rely only on seeds
   for existing databases.

6. Wire AnneAdmin authorization:

   ```ruby
   AnneAdmin.configure do |config|
     config.authorize_with do |context|
       AnneAccess.can?(
         context[:user],
         context[:action],
         context[:resource].name,
         record: context[:record]
       )
     end
   end
   ```

### Data Migration

AnneAccess migrations create these tables:

- `anne_access_roles`
- `anne_access_permissions`
- `anne_access_role_permissions`
- `anne_access_assignments`

The engine generator provides schema only. Host apps own the initial permission
matrix and any backfill from existing role columns.

### Verification

- Existing admin users can access every expected admin resource after
  `db:migrate`.
- Users without assignments are denied by default.
- Viewer or read-only users can read resources but cannot create, update, or
  destroy records.
- `AnneAccess.can?(account, :index, :customers)` returns `true` for a migrated
  admin account when `customers.manage` is assigned.

## Example App Notes

`examples/customer_management` includes host migrations that seed default
AnneAccess permissions and backfill existing `accounts.role` values. That
behavior is example-app specific; production host apps should define their own
permission matrix explicitly.
