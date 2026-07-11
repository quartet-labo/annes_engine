# AnneAdmin Authentication and Authorization

AnneAdmin does not own credentials or roles. Every request runs a required host
authentication hook, resolves the current user, and then authorizes the selected
resource action when a resource controller calls authorization.

## Safe Baseline

```ruby
AnneAdmin.configure do |config|
  config.authenticate_with do |controller|
    unless controller.send(:current_account)
      controller.redirect_to(
        controller.main_app.account_login_path,
        alert: "Login is required."
      )
    end
  end

  config.current_user do |controller|
    controller.send(:current_account)
  end

  config.authorize_with do |context|
    Policy.allowed?(
      user: context[:user],
      action: context[:action],
      resource: context[:resource].name,
      record: context[:record]
    )
  end
end
```

## Authentication Hook

`authenticate_with` is mandatory. If it is missing, AnneAdmin raises
`AnneAdmin::ConfigurationError` rather than serving the request.

The block receives the current controller. On denial it must complete the
response with `redirect_to`, `render`, or `head`. Returning `false` by itself is
not a substitute for a performed response in a Rails before-action callback.

```ruby
config.authenticate_with do |controller|
  next true if controller.send(:current_account_session)

  controller.redirect_to(controller.main_app.login_path)
  false
end
```

The final `false` documents the result for adapter callers; the redirect is what
halts the controller action. Avoid rescue clauses that convert authentication
errors into an authenticated request.

## Current User Hook

`current_user` receives the controller and returns the object passed to
authorization and audit notifications. It may return nil, but a production
authentication hook should normally prevent a nil principal from reaching a
resource action.

Use `controller.send` when the host helper is private. Keep the returned object
stable for the request because AnneAdmin memoizes it.

## Authorization Hook

`authorize_with` is optional in the runtime API. When omitted, AnneAdmin allows
the action after authentication. Configure it explicitly for every production
host that needs role, resource, tenant, or workflow restrictions.

The hook receives:

| Key | Value |
| --- | --- |
| `:user` | Memoized result of `current_user` |
| `:resource` | Current `AnneAdmin::ResourceConfig` |
| `:action` | Standard action symbol or custom action name |
| `:record` | Member record, or nil for collection/create actions |
| `:controller` | Current AnneAdmin controller |

A truthy result allows the request. A falsey result raises
`AnneAdmin::NotAuthorizedError`; the Engine application controller renders
plain `Forbidden` with HTTP 403.

Authorization is separate from record loading. Host-owned tenant or ownership
scopes must also constrain `resource_scope` and member lookup.

## AnneAuth Integration

Include the AnneAuth concern whenever Rails reloads application code:

```ruby
# config/initializers/anne_admin.rb
Rails.application.config.to_prepare do
  AnneAdmin::ApplicationController.include AnneAuth::AccountAuthentication
end

AnneAdmin.configure do |config|
  config.authenticate_with do |controller|
    controller.send(:require_verified_account)
  end

  config.current_user do |controller|
    controller.send(:current_account)
  end
end
```

Choose `require_account_authentication` instead only when unverified or
profile-incomplete accounts are intentionally allowed into the admin surface.
The concern methods are private, so `send` is the most explicit initializer
form.

If the host uses its own admin login controller, the authentication hook can
check that session and redirect to a host route instead. AnneAdmin does not
require AnneAuth.

## AnneAccess Integration

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

AnneAccess maps `index/show` to `read`, `new` to `create`, and `edit` to
`update`; the other standard names already match. A `manage` permission covers
the standard actions for the resource.

Custom action names require explicit AnneAccess permissions. `manage` does not
cover them:

```ruby
AnneAccess::Permission.create!(
  resource: "invoices",
  action: "mark_paid"
)
```

See [AnneAccess integration](../../anne_access/docs/anne-admin-integration.md)
for principal resolution and record-scope examples.

## Host Policy Integration

AnneAdmin can call any host policy layer. Normalize actions in one place and
keep collection/member behavior explicit:

```ruby
config.authorize_with do |context|
  AdminPolicy.new(context[:user], context[:record]).allowed?(
    context[:action],
    resource: context[:resource].name
  )
end
```

Do not constantize resource or action parameters from the request inside the
hook. AnneAdmin has already resolved the configured resource and registered
action; use those objects.

## Test Matrix

Cover:

- missing authentication configuration raises an error;
- unauthenticated requests perform the intended redirect or response;
- authenticated but unauthorized requests return 403;
- current user is passed to both policy and audit notification;
- read-only users cannot reach create/update/destroy;
- custom actions use their own permission name;
- cross-tenant rows cannot be listed or loaded even when coarse RBAC allows the action.
