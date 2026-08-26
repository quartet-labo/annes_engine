# AnnesAdmin Host Customization

Use the Engine defaults for standard CRUD. Move into the host only when a
resource needs tenant scoping, eager loading, a business service, an existing
route contract, or a custom presentation.

## Route Precedence

Define host routes before the Engine mount. Rails matches the earlier route and
lets unclaimed resource paths fall through to AnnesAdmin:

```ruby
Rails.application.routes.draw do
  namespace :admin do
    resources :customers, only: %i[index show edit update]
  end

  mount AnnesAdmin::Engine => "/admin", as: :annes_admin
end
```

Avoid duplicating the same path after the mount; it will be unreachable.

## Host Controller Inheritance

Inherit from `AnnesAdmin::ResourcesController` and override only the boundary
that differs:

```ruby
class Admin::CustomersController < AnnesAdmin::ResourcesController
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
app/views/annes_admin/resources/index.html.erb
```

For one host controller, select a host template:

```ruby
class Admin::CustomersController < AnnesAdmin::ResourcesController
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

## Admin Styles

The default AnnesAdmin layout loads the namespaced
`annes_admin/application` stylesheet. It defines the default layout utilities
for Engine views and the complete default, hover, disabled, and keyboard-focus
presentation for:

- `annes-admin-action annes-admin-action--primary`
- `annes-admin-action annes-admin-action--secondary`

These classes do not depend on Tailwind theme variables or on the host build
scanning Engine templates. Use them in host-owned AnnesAdmin views instead of
copying a standard Engine template only to restore button contrast.

When replacing `layouts/annes_admin/application`, preserve the Engine stylesheet
and load deliberate host overrides after it:

```erb
<%= stylesheet_link_tag "annes_admin/application", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "admin_overrides", "data-turbo-track": "reload" %>
```

The optional host stylesheet comes last when the application deliberately
changes the AnnesAdmin theme. Do not remove visible focus indicators. The
Engine stylesheet owns the standard Engine layout, forms, tables, and action
controls.

## Resource Form Submit Guard

The shared `annes_admin/resources/_form` partial opts standard create and update
forms into the Engine submit guard with:

```erb
data: { annes_admin_submit_guard: true }
```

Keep that data attribute when overriding the resource form. Do not apply it to
search GET forms, logout, member custom actions, or host-specific forms unless
the host intentionally owns their submission behavior.

When replacing `layouts/annes_admin/application`, also load the namespaced
Engine JavaScript asset before application scripts that may intercept submit:

```erb
<%= javascript_include_tag "annes_admin/submit_guard",
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
def annes_admin_resource_index_path(resource, options = {})
  return super unless resource.name == "customers"

  admin_customers_path(options)
end

def annes_admin_resource_record_path(resource, record)
  return super unless resource.name == "customers"

  admin_customer_path(record)
end

def annes_admin_edit_resource_record_path(resource, record)
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
AnnesAdmin.resource :invoices, model: "Invoice" do
  custom_action :mark_paid do |record:, controller:, **|
    Invoices::MarkPaid.call(
      invoice: record,
      actor: controller.send(:annes_admin_current_user)
    )
  end
end
```

Put transactions, retries, external integrations, and domain validation in the
host service. Let exceptions propagate to the host error handler; do not report
a successful action or audit event when the service failed.

## Reloading Resource Files

AnnesAdmin reloads configured resource files and removes earlier loader-owned
registrations before loading them again. A load failure removes the partial
loader state and re-raises the error. Keep resource files deterministic and
free of irreversible side effects.

Manual registrations through `config.resource` remain separate from
loader-owned definitions. Do not use both styles for the same resource key.
