# AnneAdmin Host Customization

Use the Engine defaults for standard CRUD. Move into the host only when a
resource needs tenant scoping, eager loading, a business service, an existing
route contract, or a custom presentation.

## Route Precedence

Define host routes before the Engine mount. Rails matches the earlier route and
lets unclaimed resource paths fall through to AnneAdmin:

```ruby
Rails.application.routes.draw do
  namespace :admin do
    resources :customers, only: %i[index show edit update]
  end

  mount AnneAdmin::Engine => "/admin", as: :anne_admin
end
```

Avoid duplicating the same path after the mount; it will be unreachable.

## Host Controller Inheritance

Inherit from `AnneAdmin::ResourcesController` and override only the boundary
that differs:

```ruby
class Admin::CustomersController < AnneAdmin::ResourcesController
  private
    def resource_name
      "customers"
    end

    def resource_scope
      super
        .where(organization_id: current_account.organization_id)
        .includes(:projects)
    end

    def resource_params
      super.except(:internal_note)
    end

    def after_update_path(record)
      admin_customer_path(record)
    end
end
```

Available lookup and assignment hooks include:

- `resource_name`
- `resource_config`
- `resource_model`
- `resource_scope`
- `build_resource_record`
- `find_resource_record`
- `assign_resource_record`
- `assign_resource_collection`
- `resource_record_variable_name`
- `resource_collection_variable_name`
- `resource_params`

Redirect hooks include `after_create_path`, `after_update_path`,
`after_destroy_path`, and `after_action_path`. The first two receive the record;
the destroy hook does not. `after_action_path` belongs to the custom-action
controller, so override it in a host action controller when needed.

Prefer `resource_scope` for tenant constraints so both collection and default
member lookup share the same relation. Override `find_resource_record` only when
lookup itself differs.

## View Overrides

To replace an Engine template for every controller, create the same path in the
host, such as:

```text
app/views/anne_admin/resources/index.html.erb
```

For one host controller, select a host template:

```ruby
class Admin::CustomersController < AnneAdmin::ResourcesController
  private
    def resource_template(action)
      "admin/customers/#{action}"
    end
end
```

The Engine assigns `@record` and `@records`. Expose resource-specific variables
for existing views:

```ruby
def resource_record_variable_name
  "customer"
end

def resource_collection_variable_name
  "customers"
end
```

This additionally assigns `@customer` or `@customers` while retaining the
generic variables.

## Action Styles

The default AnneAdmin layout loads the namespaced
`anne_admin/application` stylesheet after the host `tailwind` stylesheet. It
defines the complete default, hover, disabled, and keyboard-focus presentation
for:

- `anne-admin-action anne-admin-action--primary`
- `anne-admin-action anne-admin-action--secondary`

These classes do not depend on Tailwind theme variables or on the host build
scanning Engine templates. Use them in host-owned AnneAdmin views instead of
copying a standard Engine template only to restore button contrast.

When replacing `layouts/anne_admin/application`, preserve the order:

```erb
<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "anne_admin/application", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "admin_overrides", "data-turbo-track": "reload" %>
```

The optional host stylesheet comes last when the application deliberately
changes the AnneAdmin theme. Do not remove visible focus indicators. The
Engine stylesheet currently owns action controls only, so standard Engine
views still use the host Tailwind stylesheet for layout, forms, and tables.

## Resource Form Submit Guard

The shared `anne_admin/resources/_form` partial opts standard create and update
forms into the Engine submit guard with:

```erb
data: { anne_admin_submit_guard: true }
```

Keep that data attribute when overriding the resource form. Do not apply it to
search GET forms, logout, member custom actions, or host-specific forms unless
the host intentionally owns their submission behavior.

When replacing `layouts/anne_admin/application`, also load the namespaced
Engine JavaScript asset before application scripts that may intercept submit:

```erb
<%= javascript_include_tag "anne_admin/submit_guard",
  "data-turbo-track": "reload",
  defer: true %>
```

The guard listens for the constraint-validation-aware `submit` event, allows
the initial request, and blocks later submits while the form is busy. It
restores only the state it changed on `pageshow` and `turbo:submit-end`.
Re-evaluating the asset does not register duplicate listeners.

## Path Helper Overrides

Engine templates call overridable wrapper helpers. When a host controller uses
Engine views but owns the route, redirect links and forms to host helpers:

```ruby
def anne_admin_resource_index_path(resource, options = {})
  return super unless resource.name == "customers"

  admin_customers_path(options)
end

def anne_admin_resource_record_path(resource, record)
  return super unless resource.name == "customers"

  admin_customer_path(record)
end

def anne_admin_edit_resource_record_path(resource, record)
  return super unless resource.name == "customers"

  edit_admin_customer_path(record)
end
```

Also override new-resource or member-action wrappers when the custom view uses
those routes. Add request tests for every form method and redirect; a page can
render successfully while still posting to the wrong route.

## Service Delegation

Resource definitions should describe the admin surface, not contain a host
workflow. A small custom action can delegate:

```ruby
AnneAdmin.resource :invoices, model: "Invoice" do
  custom_action :mark_paid do |record:, controller:, **|
    Invoices::MarkPaid.call(
      invoice: record,
      actor: controller.send(:anne_admin_current_user)
    )
  end
end
```

Put transactions, retries, external integrations, and domain validation in the
host service. Let exceptions propagate to the host error handler; do not report
a successful action or audit event when the service failed.

## Reloading Resource Files

AnneAdmin reloads configured resource files and removes earlier loader-owned
registrations before loading them again. A load failure removes the partial
loader state and re-raises the error. Keep resource files deterministic and
free of irreversible side effects.

Manual registrations through `config.resource` remain separate from
loader-owned definitions. Do not use both styles for the same resource key.
