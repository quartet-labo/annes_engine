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
