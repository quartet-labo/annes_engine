# AnnesAdmin Authentication and Authorization

AnnesAdmin does not own credentials or roles. Every request runs a required host
authentication hook, resolves the current user, and then authorizes the selected
resource action when a resource controller calls authorization.

## Safe Baseline

```ruby
AnnesAdmin.configure do |config|
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

`authenticate_with` is mandatory. If it is missing, AnnesAdmin raises
`AnnesAdmin::ConfigurationError` rather than serving the request.

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
stable for the request because AnnesAdmin memoizes it.

## Authorization Hook

`authorize_with` is optional in the runtime API. When omitted, AnnesAdmin allows
the action after authentication. Configure it explicitly for every production
host that needs role, resource, tenant, or workflow restrictions.

The hook receives:

| Key | Value |
| --- | --- |
| `:user` | Memoized result of `current_user` |
| `:resource` | Current `AnnesAdmin::ResourceConfig` |
| `:action` | Standard action symbol or custom action name |
| `:record` | Member record, or nil for collection/create actions |
| `:controller` | Current AnnesAdmin controller |

A truthy result allows the request. A falsey result raises
`AnnesAdmin::NotAuthorizedError`; the Engine application controller renders
plain `Forbidden` with HTTP 403.

Authorization is separate from record loading. Host-owned tenant or ownership
scopes must also constrain `resource_scope` and member lookup.

### Dashboard and Navigation

The default home controller requires authentication but does not call the
resource authorization hook. The default dashboard and layout navigation list
all registered resource names; opening a resource action still runs
authorization and can return 403.

If merely revealing a resource name is sensitive, or navigation must differ by
role, override the dashboard/layout in the host and filter links with the same
policy. Do not treat hidden navigation as authorization—the resource action
must remain protected.

## AnnesAuth Integration

Include the AnnesAuth concern whenever Rails reloads application code:

```ruby
# config/initializers/annes_admin.rb
Rails.application.config.to_prepare do
  AnnesAdmin::ApplicationController.include AnnesAuth::AccountAuthentication
end

AnnesAdmin.configure do |config|
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
check that session and redirect to a host route instead. AnnesAdmin does not
require AnnesAuth.

## AnnesAccess Integration

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

AnnesAccess maps `index/show` to `read`, `new` to `create`, and `edit` to
`update`; the other standard names already match. A `manage` permission covers
the standard actions for the resource.

Custom action names require explicit AnnesAccess permissions. `manage` does not
cover them:

```ruby
AnnesAccess::Permission.create!(
  resource: "invoices",
  action: "mark_paid"
)
```

See the
[AnnesAccess integration guide](https://github.com/quartet-labo/annes_engine/blob/main/annes_access/docs/annes-admin-integration.md)
for principal resolution and record-scope examples. The absolute repository
link remains valid when this guide is read from an installed AnnesAdmin gem.

## Host Policy Integration

AnnesAdmin can call any host policy layer. Normalize actions in one place and
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
hook. AnnesAdmin has already resolved the configured resource and registered
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
