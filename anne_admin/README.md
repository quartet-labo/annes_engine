# AnneAdmin

AnneAdmin is a mountable Rails engine for building configurable admin screens.

The engine does not own application domain models. Host applications register resources, authentication, authorization, fields, and custom actions through configuration.

## Requirements

- Ruby 3.4 or newer
- Rails 8.1

## Documentation

- [Resource DSL reference](docs/resource-dsl.md)
- [Authentication and authorization](docs/authentication-and-authorization.md)
- [Host customization](docs/customization.md)
- [Queries, actions, and audit events](docs/query-actions-and-audit.md)
- [Security checklist](docs/security-checklist.md)
- [Upgrade guide](UPGRADING.md)

## Quick Start

Add the engine to the host app.

```ruby
source "https://rubygems.org"

source "https://rubygems.pkg.github.com/quartet-labo" do
  gem "anne_admin", "~> 0.2.0"
end
```

Configure Bundler credentials before installing. Use a token with
`read:packages` access.

```sh
bundle config https://rubygems.pkg.github.com/quartet-labo GITHUB_USERNAME:GITHUB_PACKAGES_TOKEN
```

For local development from a host application, use a path source:

```ruby
gem "anne_admin", path: "../anne_engine/anne_admin"
```

Run the installer:

```sh
bin/rails generate anne_admin:install
```

The installer creates:

- `config/initializers/anne_admin.rb`;
- `app/admin/resources/users.rb` as an example resource;
- an AnneAdmin mount in `config/routes.rb` if one is not already present.

The generated resource assumes the host has a `User` model with `email` and
`created_at`. Replace its model and fields immediately when that assumption does
not match the host. An unmodified example can fail during resource loading.

The resulting mount is:

```ruby
mount AnneAdmin::Engine => "/admin", as: :anne_admin
```

The installer adds this mount route if it is not already present. When migrating an existing `/admin` namespace, define host routes before the engine mount. Host routes keep their behavior, and unclaimed resources can fall through to the engine.

Before opening `/admin`, replace the generated deny placeholder with real
authentication and explicit authorization. Authentication is required and
raises `AnneAdmin::ConfigurationError` when missing. Authorization is optional
at runtime and therefore allows every authenticated request when omitted; a
production host should configure it deliberately.

## Configuration

Authentication must be configured explicitly. The engine raises `AnneAdmin::ConfigurationError` if `authenticate_with` is missing.

```ruby
AnneAdmin.configure do |config|
  config.site_name = "Admin"

  config.authenticate_with do |controller|
    controller.require_account_authentication
  end

  config.current_user do |controller|
    controller.current_account
  end

  config.authorize_with do |context|
    # context keys: :user, :resource, :action, :record, :controller
    true
  end
end
```

When using `anne_auth`, include its authentication concern into the controller
that AnneAdmin uses before configuring these hooks.

After adapting the sample resource, open `/admin`. The navigation should show
the registered resource and the index action should pass through both hooks.
See [Authentication and authorization](docs/authentication-and-authorization.md)
before enabling write actions in production.

## Resource DSL

Register host application models as resources. Resource files are loaded from
`app/admin/resources/**/*.rb` and `config/anne_admin/resources/**/*.rb` by
default.

```ruby
# app/admin/resources/customers.rb
AnneAdmin.resource :customers, model: "Customer" do
  label "Customers"
  actions :index, :show, :edit, :update
  field :company_name, searchable: true, sortable: true
  field :contact_name, searchable: true, sortable: true
  field :email, searchable: true, sortable: true
  field :updated_at, type: :datetime, permitted: false, sortable: true
  permitted_attributes :company_name, :contact_name, :email
end
```

Files are loaded in sorted path order, so use prefixes such as
`01_customers.rb` when navigation order matters. Each resource key can be
registered only once; duplicate definitions raise `AnneAdmin::ConfigurationError`.

For additional directories, append to `config.resource_paths` in the initializer.
The existing `config.resource` DSL remains supported for small applications and
manual registrations.

Only `permitted_attributes` can be written through create/update. Search and sort parameters are constrained to configured allowlists.

## Host Overrides

AnneAdmin provides the minimum shared admin foundation: authentication, authorization, resource configuration, generic CRUD, search, sort, forms, and audit notifications.

Keep application-specific workflows in the host app. When one resource needs custom behavior, define a host route before the engine mount. Earlier host routes take precedence and the remaining resources continue to use the engine.

```ruby
namespace :admin, path: "admin" do
  resources :customers, only: %i[index show edit update]
end

mount AnneAdmin::Engine => "/admin", as: :anne_admin
```

The host controller can inherit from `AnneAdmin::ResourcesController` and override only the parts that differ.

```ruby
class Admin::CustomersController < AnneAdmin::ResourcesController
  private
    def resource_name
      "customers"
    end

    def resource_scope
      super.includes(:projects).order(contact_name: :asc)
    end

    def resource_params
      super.except(:memo)
    end

    def after_update_path(record)
      admin_customer_path(record)
    end
end
```

Available resource hooks are:

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
- `after_create_path`
- `after_update_path`
- `after_destroy_path`
- `after_action_path`

### View Overrides

Use the engine views as-is for standard CRUD screens. To replace all engine resource views, define templates at the same paths in the host app, such as `app/views/anne_admin/resources/index.html.erb`.

For a single host controller, override `resource_template`:

```ruby
class Admin::CustomersController < AnneAdmin::ResourcesController
  private
    def resource_template(action)
      "admin/customers/#{action}"
    end
end
```

When reusing existing host views, you can keep the engine's `@record` / `@records` assignments and also expose resource-specific variables:

```ruby
class Admin::ProjectsController < AnneAdmin::ResourcesController
  private
    def resource_template(action)
      "admin/projects/#{action}"
    end

    def resource_record_variable_name
      "project"
    end

    def resource_collection_variable_name
      "projects"
    end
end
```

When a host controller keeps the engine templates but owns the route, override the view path helpers so links and forms stay on the host route:

```ruby
class Admin::CustomersController < AnneAdmin::ResourcesController
  private
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
end
```

### Service Delegation

For business workflows, prefer host controllers and host services. Use custom actions only for generic resource actions that belong in the configurable engine surface. The engine should not reference host-specific service constants directly.

## Package Boundary

AnneAdmin owns the reusable admin framework surface only: resource configuration, generic CRUD, field rendering, search, sort, pagination, authentication hooks, authorization hooks, and audit notifications.

Runtime code must not reference host application domain constants such as `Customer`, `Project`, `Quotation`, or `QuoteRequest`. Register host models through `AnneAdmin.configure` and keep application-specific workflows in host controllers or services.

## Release Workflow

The distribution target is GitHub Packages. Use this flow for releases:

1. Run the engine test suite from the engine repository with `bundle exec rake test`.
2. Update `lib/anne_admin/version.rb` to the version you want to publish.
3. Update `CHANGELOG.md` for that version.
4. Commit the release.
5. Push a gem-specific tag such as `anne_admin-vX.Y.Z`, matching `AnneAdmin::VERSION`.
6. Confirm the `Publish Gems` workflow published the package to GitHub Packages
   and created the GitHub Release for the tag.
7. Update host applications with `bundle update anne_admin` and run their full test suites.

The workflow fails if the tag version does not match `AnneAdmin::VERSION`. You
can also run the `Publish Gems` workflow manually and choose `anne_admin`;
manual runs publish the version currently defined by the gemspec without
creating a GitHub Release.

## Custom Actions

Custom actions let the host app attach small configured actions to a resource.

```ruby
config.resource :customers, model: "Customer" do
  custom_action :mark_reviewed, method: :post, scope: :member, label: "Mark reviewed" do |record:, **|
    record.update!(reviewed_at: Time.current)
  end
end
```

Create, update, destroy, and custom actions emit `anne_admin.audit` notifications with resource, action, record id, user id, and status.

## Security Notes

- Configure authentication before mounting in production.
- Keep authorization rules in the host app through `authorize_with`.
- Register only fields that are safe to display.
- Write access is limited by `permitted_attributes`; do not include sensitive columns.
- Business actions should call host services instead of adding domain logic to the engine.

## AnneAccess Integration

Host apps can centralize admin permissions with `anne_access` and keep
AnneAdmin focused on resource screens.

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

AnneAdmin passes resource names and controller actions to the hook. AnneAccess
maps standard controller actions such as `index`, `show`, `new`, and `edit` to
RBAC actions such as `read`, `create`, and `update`.
