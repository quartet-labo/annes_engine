# AnnesAdmin Upgrade Guide

This guide lists manual steps required when upgrading AnnesAdmin in a host
application. Use `CHANGELOG.md` for the full list of code changes; use this file
for actions the host app must perform.

## General Upgrade Checklist

1. Update the host app `Gemfile` version or path.
2. Run `bundle update annes_admin`.
3. Review `config/initializers/annes_admin.rb`.
4. Review resource definitions under `app/admin/resources` or
   `config/annes_admin/resources`.
5. Run the host app admin test suite.

AnnesAdmin usually does not ship host DB migrations. If a release has no manual
steps, no action is needed beyond updating the gem and running tests.

## 0.2.x -> 1.0.0

### Who Is Affected

Every host application using the former `anne_admin` gem must make this
breaking package and namespace migration.

### Required Steps

1. Replace the dependency with `gem "annes_admin", "~> 1.0"` and run
   `bundle update annes_admin`.
2. Rename `config/initializers/anne_admin.rb` to
   `config/initializers/annes_admin.rb`, and replace `AnneAdmin` with
   `AnnesAdmin` throughout the initializer and host code.
3. Update routes to `mount AnnesAdmin::Engine => "/admin", as: :annes_admin`.
4. Update host view overrides from `layouts/anne_admin/...` and
   `anne_admin/resources/...` to the corresponding `annes_admin` paths.
5. Replace the asset logical paths with `annes_admin/application` and
   `annes_admin/submit_guard`, and replace CSS classes beginning with
   `anne-admin-` with `annes-admin-`.
6. Update audit subscribers to listen for `annes_admin.audit`.
7. Rebuild or precompile assets, then run the host admin test suite.

No host database migration is required.

### Verification

- `bin/rails routes` lists the `annes_admin` engine mount.
- The admin layout loads its stylesheet and submit-guard JavaScript.
- Resource screens render and their audit notifications use
  `annes_admin.audit`.

## 0.2.2 -> 0.2.3

### Who Is Affected

Host apps that use the standard AnnesAdmin new/edit resource form get repeated
submission protection automatically. Hosts that override
`annes_admin/resources/_form` or `layouts/annes_admin/application` should review
the required steps below.

### Required Steps

1. If the host overrides `annes_admin/resources/_form`, preserve
   `data-annes-admin-submit-guard` on the create/update form.
2. If the host overrides `layouts/annes_admin/application`, load the Engine
   JavaScript asset:

   ```erb
   <%= javascript_include_tag "annes_admin/submit_guard",
     "data-turbo-track": "reload",
     defer: true %>
   ```

No host DB migration is required.

## 0.2.1 -> 0.2.2

### Who Is Affected

All host apps using AnnesAdmin standard resource actions should update. Hosts
that override `layouts/annes_admin/application`, standard resource views, or
Tailwind source configuration need the additional checks below.

### Behavior Change

AnnesAdmin now ships a namespaced `annes_admin/application` stylesheet for
primary and secondary action controls. Standard resource actions no longer
depend on the host Tailwind build scanning templates inside the installed gem
for their background, text, border, hover, disabled, and keyboard-focus styles.

### Required Steps

1. Update AnnesAdmin and rebuild or precompile host assets:

   ```sh
   bundle update annes_admin
   bin/rails assets:precompile
   ```

2. If the host overrides `layouts/annes_admin/application`, load the Engine
   stylesheet before any deliberate host theme override:

   ```erb
   <%= stylesheet_link_tag "annes_admin/application", "data-turbo-track": "reload" %>
   <%= stylesheet_link_tag "admin_overrides", "data-turbo-track": "reload" %>
   ```

3. Remove resource view overrides created only to restore standard action
   contrast. Returning to the standard views also preserves the
   authorization-aware `new`, `edit`, and member custom action visibility
   introduced in 0.2.1.

4. After confirming the Engine stylesheet is loaded, remove Tailwind
   `safelist`, `@source`, or equivalent entries that were added only for
   AnnesAdmin action utilities.

5. Host-owned action views can opt into the Engine presentation with:

   - `annes-admin-action annes-admin-action--primary`
   - `annes-admin-action annes-admin-action--secondary`

No host DB migration or resource definition change is required.

### Verification

- Standard `new`, search, `edit`, and save actions retain visible default,
  hover, and keyboard-focus states without scanning gem templates in Tailwind.
- List, back, and member custom actions have visible borders and focus
  indicators.
- Users without create or update permission still do not see the corresponding
  standard actions.
- A host layout override serves `annes_admin/application` successfully.

## 0.2.0 -> 0.2.1

### Who Is Affected

Host apps that configure `authorize_with`, especially callbacks that record an
event or assume they are called only while processing the target action.

### Behavior Change

AnnesAdmin now calls the configured authorization hook while rendering action
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
   `annes_admin_authorized?(action, record: nil)` for the same visibility
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

Host apps using AnnesAdmin resource definitions or relying on the install
generator.

### Required Steps

1. Keep global settings in `config/initializers/annes_admin.rb`:

   - `site_name`
   - `authenticate_with`
   - `current_user`
   - `authorize_with`
   - optional `resource_paths`

2. Prefer moving resource definitions to:

   - `app/admin/resources/*.rb`
   - `config/annes_admin/resources/*.rb`

3. Use the top-level resource DSL in resource files:

   ```ruby
   AnnesAdmin.resource :customers, model: "Customer" do
     label "Customers"
     field :name, searchable: true
     permitted_attributes :name
   end
   ```

4. Ensure each resource key is defined only once. Duplicate keys raise
   `AnnesAdmin::ConfigurationError`.

5. If using `annes_access`, wire authorization through `authorize_with`:

   ```ruby
   config.authorize_with do |context|
     AnnesAccess.can?(
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
