# AnnesAccess

AnnesAccess is a lightweight RBAC Rails engine for Annes Engine applications.

It provides role, permission, and assignment models plus a small Ability API for
checking whether an authenticated principal can perform an action on a resource.
It intentionally does not handle login, sessions, ownership rules, tenant
scopes, or complex business workflow authorization.

## Requirements

- Ruby 3.4 or newer
- Rails 8.1

## Documentation

- [RBAC setup](docs/rbac-setup.md)
- [Role and permission templates](docs/role-and-permission-templates.md)
- [Configuration and API reference](docs/configuration-and-api.md)
- [Record scoping](docs/record-scoping.md)
- [AnnesAdmin integration](docs/annes-admin-integration.md)
- [Security checklist](docs/security-checklist.md)
- [Upgrade guide](UPGRADING.md)

## Quick Start

Add the engine to the host app.

```ruby
source "https://rubygems.org"

source "https://rubygems.pkg.github.com/quartet-labo" do
  gem "annes_access", "~> 1.0"
end
```

Configure Bundler with a GitHub token that has `read:packages` access:

```sh
bundle config https://rubygems.pkg.github.com/quartet-labo GITHUB_USERNAME:GITHUB_PACKAGES_TOKEN
```

For local development, use `gem "annes_access", path: "../anne_engine/annes_access"`.

Run the installer.

```sh
bin/rails generate annes_access:install
bin/rails db:migrate
```

The installer copies:

- `config/initializers/annes_access.rb`
- legacy `db/migrate/*_create_anne_access_*.rb` files followed by the
  `*_rename_anne_access_tables_to_annes_access.rb` transition
- `db/seeds/annes_access.rb`

Review the generated permission matrix, then load it from the host seed file:

```ruby
# db/seeds.rb
load Rails.root.join("db/seeds/annes_access.rb")
```

```sh
bin/rails db:seed
```

The example creates a small `role_permissions` matrix with `admin` and `viewer`
roles for `customers` and `projects`. Adapt those role names, resource keys, and
actions before using it in a real host. See
[Role and permission templates](docs/role-and-permission-templates.md) for
semi-order base-app examples.

Finally, assign a role to a persisted authentication principal:

```ruby
account = Account.find_by!(email: "admin@example.com")
admin = AnnesAccess::Role.find_by!(key: "admin")

AnnesAccess::Assignment.find_or_create_by!(principal: account, role: admin)

AnnesAccess.can?(account, :read, :customers) # => true
AnnesAccess.can?(nil, :read, :customers)     # => false
```

Roles do not grant anything until permissions are connected through
`AnnesAccess::RolePermission`. See [RBAC setup](docs/rbac-setup.md) for a full,
idempotent seed and migration guidance.

## Configuration

```ruby
AnnesAccess.configure do |config|
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
that can be stored by the polymorphic `AnnesAccess::Assignment` association.

## Usage

```ruby
AnnesAccess.can?(current_account, :read, :customers)
AnnesAccess.can?(current_account, :update, :projects, record: project)
AnnesAccess.authorize!(current_account, :destroy, :customers)
```

`manage` grants all standard actions for the same resource.

```ruby
AnnesAccess::Permission.create!(resource: "projects", action: "manage")
```

## Host-Owned Record Scopes

AnnesAccess answers the coarse RBAC question: can this principal perform this
action on this resource? Host applications own business-specific record scopes,
such as ownership, tenant boundaries, customer visibility, and account
membership rules.

For index and list actions, `record` is usually `nil`. AnnesAccess does not
generate an `ActiveRecord` scope or `accessible_by` query for those collection
actions. Apply host-owned scopes in the controller or query layer before loading
records.

```ruby
@products = Product.visible_to_customer(current_user).ordered

@product = Product.visible_to_customer(current_user).find(params[:id])
```

For member actions such as show, update, and destroy, pass the loaded record to
AnnesAccess and use `custom_rule` when the host app needs a final record-level
visibility check.

```ruby
AnnesAccess.configure do |config|
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
  include AnnesAccess::Authorization

  def update
    @project = Project.find(params[:id])
    authorize_access! :update, :projects, record: @project
  end
end
```

The default principal lookup tries `current_account`, then `current_user`. Host
controllers can override `current_access_principal`.

If authentication and authorization use different principals, configure a
resolver instead. For example, an app can keep `AnnesAuth::Account` as the login
and session principal while authorizing against the host app's `User` model.

```ruby
AnnesAccess.configure do |config|
  config.principal_resolver = ->(controller) { controller.send(:current_user) }
end
```

When `principal_resolver` is configured, its return value is used directly. A
`nil` return value keeps the default deny behavior.

## AnnesAdmin

```ruby
AnnesAdmin.configure do |config|
  config.authorize_with do |context|
    AnnesAccess.can?(
      context[:user],
      context[:action],
      context[:resource].name,
      record: context[:record]
    )
  end
end
```

Keep business-specific record ownership, tenant scoping, and workflow rules in
the host application through `custom_rule` or host controllers. AnnesAccess
should remain the coarse RBAC layer, not the source of host-specific record
visibility rules.

## Release Workflow

The distribution target is GitHub Packages. Use this flow for releases:

1. Run the engine test suite from the engine repository with `bundle exec rake test`.
2. Update `lib/annes_access/version.rb` to the version you want to publish.
3. Update `CHANGELOG.md` and `UPGRADING.md` for that version.
4. Update the dependent example app lockfiles by running `bundle update annes_access`
   from `examples/customer_management`, `examples/resavation_management`, and
   `examples/restaurant_loyalty`.
5. Commit the release, including the changed example `Gemfile.lock` files.
6. Run the `Publish Gems` workflow with the `workflow_dispatch` trigger,
   selecting the `main` ref, `gem` = `annes_access`, and `version` equal to
   `AnnesAccess::VERSION`.
7. Confirm the workflow published the package to GitHub Packages. The same
   workflow creates the gem-specific tag and GitHub Release for that version.
8. Update host applications with `bundle update annes_access` and run their full test suites.

The workflow fails before publishing if the `version` input does not match
`AnnesAccess::VERSION`, the changelog section is missing or empty, or the remote
gem-specific tag already exists. Tag push events are not the release entrypoint.

## License and Support

AnnesAccess is available under the
[MIT License](https://github.com/quartet-labo/anne_engine/blob/main/MIT-LICENSE).
Open-source use does not include support, maintenance, fixes, compatibility
guarantees, or release commitments. See the shared
[support policy](https://github.com/quartet-labo/anne_engine/blob/main/SUPPORT.md)
for community-use boundaries and separately available paid services.
