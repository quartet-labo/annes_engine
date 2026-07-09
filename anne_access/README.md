# AnneAccess

AnneAccess is a lightweight RBAC Rails engine for Anne Engine applications.

It provides role, permission, and assignment models plus a small Ability API for
checking whether an authenticated principal can perform an action on a resource.
It intentionally does not handle login, sessions, ownership rules, tenant
scopes, or complex business workflow authorization.

## Installation

Add the engine to the host app.

```ruby
gem "anne_access", path: "../anne_engine/anne_access"
```

Run the installer.

```sh
bin/rails generate anne_access:install
bin/rails db:migrate
```

The installer copies:

- `config/initializers/anne_access.rb`
- `db/migrate/*_create_anne_access_*.rb`

## Configuration

```ruby
AnneAccess.configure do |config|
  config.principal_class_names = ["Account"]
  config.super_admin_role_keys = []
  config.default_role_key = nil
end
```

The default behavior is deny. Nil principals, unknown resources, and unknown
actions are not authorized.

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
