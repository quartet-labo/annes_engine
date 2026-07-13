# AnneAdmin Upgrade Guide

This guide lists manual steps required when upgrading AnneAdmin in a host
application. Use `CHANGELOG.md` for the full list of code changes; use this file
for actions the host app must perform.

## General Upgrade Checklist

1. Update the host app `Gemfile` version or path.
2. Run `bundle update anne_admin`.
3. Review `config/initializers/anne_admin.rb`.
4. Review resource definitions under `app/admin/resources` or
   `config/anne_admin/resources`.
5. Run the host app admin test suite.

AnneAdmin usually does not ship host DB migrations. If a release has no manual
steps, no action is needed beyond updating the gem and running tests.

## 0.2.0 -> 0.2.1

### Who Is Affected

Host apps that configure `authorize_with`, especially callbacks that record an
event or assume they are called only while processing the target action.

### Behavior Change

AnneAdmin now calls the configured authorization hook while rendering action
controls:

- `:new` on a resource index page
- `:edit` on a resource show page, with the record in the context
- each member custom action on a resource show page, with the record in the
  context

A false result hides the corresponding link or button. Controller actions
still run authorization independently, so direct requests rejected by the hook
continue to return `403 Forbidden`.

### Required Steps

1. Ensure `authorize_with` is a side-effect-free predicate that returns a
   truthy or falsey result for every action it receives.
2. Ensure member custom action names are handled if the host registers custom
   actions.
3. If the host provides custom resource templates, use
   `anne_admin_authorized?(action, record: nil)` for the same visibility
   decision as the standard templates.

No host DB migration or resource definition change is required.

### Verification

- A user with create permission sees the `new` link; a user without it does
  not.
- A user with update permission sees the `edit` link; a user without it does
  not.
- Member custom action buttons follow their action-specific permissions.
- Direct requests without permission still return `403 Forbidden`.

## 0.1.x -> 0.2.0

### Who Is Affected

Host apps using AnneAdmin resource definitions or relying on the install
generator.

### Required Steps

1. Keep global settings in `config/initializers/anne_admin.rb`:

   - `site_name`
   - `authenticate_with`
   - `current_user`
   - `authorize_with`
   - optional `resource_paths`

2. Prefer moving resource definitions to:

   - `app/admin/resources/*.rb`
   - `config/anne_admin/resources/*.rb`

3. Use the top-level resource DSL in resource files:

   ```ruby
   AnneAdmin.resource :customers, model: "Customer" do
     label "Customers"
     field :name, searchable: true
     permitted_attributes :name
   end
   ```

4. Ensure each resource key is defined only once. Duplicate keys raise
   `AnneAdmin::ConfigurationError`.

5. If using `anne_access`, wire authorization through `authorize_with`:

   ```ruby
   config.authorize_with do |context|
     AnneAccess.can?(
       context[:user],
       context[:action],
       context[:resource].name,
       record: context[:record]
     )
   end
   ```

### Verification

- `/admin` renders.
- Resource navigation appears in the expected order.
- Each configured resource index / show page renders.
- Unauthorized users receive `403 Forbidden`.

## No Manual Steps

For releases that only change internal rendering, field behavior, or tests, run
the normal test suite after updating the gem. No host migration is required
unless the release notes explicitly say so.
