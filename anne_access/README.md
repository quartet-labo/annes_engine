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
  config.principal_resolver = nil
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
