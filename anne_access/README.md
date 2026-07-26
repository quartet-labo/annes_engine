# AnneAccess

AnneAccess is a lightweight RBAC Rails engine for Anne Engine applications.

It provides role, permission, and assignment models plus a small Ability API for
checking whether an authenticated principal can perform an action on a resource.
It intentionally does not handle login, sessions, ownership rules, tenant
scopes, or complex business workflow authorization.

## Requirements

- Ruby 3.4 or newer
- Rails 8.1

## Documentation

- [RBAC setup](docs/rbac-setup.md)
- [Configuration and API reference](docs/configuration-and-api.md)
- [Record scoping](docs/record-scoping.md)
- [AnneAdmin integration](docs/anne-admin-integration.md)
- [Security checklist](docs/security-checklist.md)
- [Upgrade guide](UPGRADING.md)

## Quick Start

Add the engine to the host app.

```ruby
source "https://rubygems.org"

source "https://rubygems.pkg.github.com/quartet-labo" do
  gem "anne_access", "~> 0.1.2"
end
```

Configure Bundler with a GitHub token that has `read:packages` access:

```sh
bundle config https://rubygems.pkg.github.com/quartet-labo GITHUB_USERNAME:GITHUB_PACKAGES_TOKEN
```

For local development, use `gem "anne_access", path: "../anne_engine/anne_access"`.

Run the installer.

```sh
bin/rails generate anne_access:install
bin/rails db:migrate
```

The installer copies:

- `config/initializers/anne_access.rb`
- `db/migrate/*_create_anne_access_*.rb`
- `db/seeds/anne_access.rb`

Review the generated permission matrix, then load it from the host seed file:

```ruby
# db/seeds.rb
load Rails.root.join("db/seeds/anne_access.rb")
```

```sh
bin/rails db:seed
```

The example creates `admin` and `viewer` roles for `customers` and `projects`.
Adapt those names before using it in a real host.

Finally, assign a role to a persisted authentication principal:

```ruby
account = Account.find_by!(email: "admin@example.com")
admin = AnneAccess::Role.find_by!(key: "admin")

AnneAccess::Assignment.find_or_create_by!(principal: account, role: admin)

AnneAccess.can?(account, :read, :customers) # => true
AnneAccess.can?(nil, :read, :customers)     # => false
```

Roles do not grant anything until permissions are connected through
`AnneAccess::RolePermission`. See [RBAC setup](docs/rbac-setup.md) for a full,
idempotent seed and migration guidance.

## Configuration

```ruby
AnneAccess.configure do |config|
  config.principal_class_names = ["Account"]
  config.principal_resolver = nil
  config.super_admin_role_keys = []
  config.default_role_key = nil
end
```

The default behavior is deny. Nil principals, unknown resources, and unknown
actions are not authorized.

`principal_class_names` documents expected host principal classes for host
configuration and future tooling. Runtime checks accept any persisted object
that can be stored by the polymorphic `AnneAccess::Assignment` association.

## Usage

```ruby
AnneAccess.can?(current_account, :read, :customers)
AnneAccess.can?(current_account, :update, :projects, record: project)
AnneAccess.authorize!(current_account, :destroy, :customers)
```

`manage` grants all standard actions for the same resource.

```ruby
AnneAccess::Permission.create!(resource: "projects", action: "manage")
```

## Host-Owned Record Scopes

AnneAccess answers the coarse RBAC question: can this principal perform this
action on this resource? Host applications own business-specific record scopes,
such as ownership, tenant boundaries, customer visibility, and account
membership rules.

For index and list actions, `record` is usually `nil`. AnneAccess does not
generate an `ActiveRecord` scope or `accessible_by` query for those collection
actions. Apply host-owned scopes in the controller or query layer before loading
records.

```ruby
@products = Product.visible_to_customer(current_user).ordered

@product = Product.visible_to_customer(current_user).find(params[:id])
```

For member actions such as show, update, and destroy, pass the loaded record to
AnneAccess and use `custom_rule` when the host app needs a final record-level
visibility check.

```ruby
AnneAccess.configure do |config|
  config.custom_rule = ->(principal:, action:, resource:, record:, allowed:) {
    return false unless allowed

    if resource == "products" && action == "read" && record.present?
      Product.visible_to_customer(principal).where(id: record.id).exists?
    else
      allowed
    end
  }
end
```

## Controller Helpers

```ruby
class Admin::ProjectsController < ApplicationController
  include AnneAccess::Authorization

  def update
    @project = Project.find(params[:id])
    authorize_access! :update, :projects, record: @project
  end
end
```

The default principal lookup tries `current_account`, then `current_user`. Host
controllers can override `current_access_principal`.

If authentication and authorization use different principals, configure a
resolver instead. For example, an app can keep `AnneAuth::Account` as the login
and session principal while authorizing against the host app's `User` model.

```ruby
AnneAccess.configure do |config|
  config.principal_resolver = ->(controller) { controller.send(:current_user) }
end
```

When `principal_resolver` is configured, its return value is used directly. A
`nil` return value keeps the default deny behavior.

## AnneAdmin

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

Keep business-specific record ownership, tenant scoping, and workflow rules in
the host application through `custom_rule` or host controllers.

## License and Support

AnneAccess is available under the
[MIT License](https://github.com/quartet-labo/anne_engine/blob/main/MIT-LICENSE).
Open-source use does not include support, maintenance, fixes, compatibility
guarantees, or release commitments. See the shared
[support policy](https://github.com/quartet-labo/anne_engine/blob/main/SUPPORT.md)
for community-use boundaries and separately available paid services.
