# AnnesAccess Configuration and API

## Configuration

```ruby
AnnesAccess.configure do |config|
  config.principal_class_names = ["Account"]
  config.principal_resolver = nil
  config.super_admin_role_keys = []
  config.default_role_key = nil
  config.action_aliases = AnnesAccess::Configuration::DEFAULT_ACTION_ALIASES.dup
  config.custom_rule = nil
end
```

| Setting | Default | Effect |
| --- | --- | --- |
| `principal_class_names` | `[]` | Documents expected host principal classes for configuration and future tooling. It does not restrict runtime checks. |
| `principal_resolver` | `nil` | Optional callable receiving a controller. Its result becomes the controller concern principal. |
| `super_admin_role_keys` | `[]` | Role keys that bypass every permission query. Keep empty unless an audited bypass is required. |
| `default_role_key` | `nil` | Existing role implicitly added to every valid persisted principal, in addition to explicit assignments. |
| `action_aliases` | standard controller aliases | Map incoming action names before permission lookup. |
| `custom_rule` | `nil` | Final callable receiving normalized context and the coarse RBAC result. |

`AnnesAccess.reset_configuration!` restores these defaults and is useful in test
teardown.

### Principal Resolution

The controller concern resolves `current_account`, then `current_user`, when no
resolver is configured. Configure a resolver when authentication and
authorization use different objects:

```ruby
AnnesAccess.configure do |config|
  config.principal_resolver = ->(controller) {
    controller.send(:current_user)
  }
end
```

When configured, the resolver result is used directly. A `nil` result does not
fall back to `current_account` or `current_user`; authorization remains denied.
Exceptions from the resolver propagate so configuration failures are visible.

`principal_class_names` is descriptive. Runtime authorization accepts any
persisted object with an ID and looks for polymorphic assignments to it.

### Default and Super-Admin Roles

`default_role_key` grants one existing role to every valid persisted principal
without creating assignments. Use it only for permissions that are safe for all
authenticated principals. An unknown key grants nothing.

`super_admin_role_keys` bypasses resource and action lookup when any assigned or
default role has a matching key. Never make the default role a super-admin role.
Changes to bypass keys should be reviewed and audited like application code.

### Custom Rules

A custom rule receives keyword arguments:

```ruby
config.custom_rule = ->(principal:, action:, resource:, record:, allowed:) {
  return false unless allowed

  if resource == "projects" && action == "read" && record
    Project.visible_to(principal).where(id: record.id).exists?
  else
    true
  end
}
```

`action` and `resource` are normalized strings. `allowed` is the result of the
role/permission check. The custom rule's return value becomes the final answer.
It can therefore accidentally turn an RBAC deny into an allow. Start with
`return false unless allowed` unless the explicit purpose of the rule is to
grant a separately reviewed exception.

A custom rule receives `record: nil` for collection checks and does not scope
an Active Record relation. See [Record scoping](record-scoping.md).

## Action Mapping

Incoming actions are stripped, lowercased, and mapped with `action_aliases`.
The defaults are:

| Incoming action | Permission action |
| --- | --- |
| `index` | `read` |
| `show` | `read` |
| `new` | `create` |
| `edit` | `update` |

Other action names remain unchanged. Resource names are also stripped and
lowercased. Keep the configured permission matrix in the same plural naming
convention used by controllers and AnneAdmin resources.

`manage` participates only when the normalized action is one of `read`,
`create`, `update`, `destroy`, or `manage`. It does not grant a custom action:

```ruby
AnnesAccess.can?(account, :index, :projects)   # projects.manage may grant this
AnnesAccess.can?(account, :approve, :projects) # requires projects.approve
```

Extend aliases without discarding defaults:

```ruby
config.action_aliases =
  AnnesAccess::Configuration::DEFAULT_ACTION_ALIASES.merge(export: :read)
```

## Module API

### `AnnesAccess.can?`

```ruby
AnnesAccess.can?(principal, action, resource, record: nil)
```

Returns the final rule result. Nil principals, objects without a persisted ID,
blank actions/resources, missing assignments, and unknown permissions deny by
default unless a custom rule explicitly overrides the result.

### `AnnesAccess.authorize!`

```ruby
AnnesAccess.authorize!(principal, :update, :projects, record: project)
```

Returns `true` when allowed and raises `AnnesAccess::NotAuthorizedError` when
denied.

### `AnnesAccess.ability_for`

```ruby
ability = AnnesAccess.ability_for(account)
ability.can?(:read, :projects)
```

An ability memoizes assigned role IDs. Create a new ability after changing
assignments in the same request or job.

## Controller Concern

```ruby
class Admin::ProjectsController < ApplicationController
  include AnnesAccess::Authorization

  def update
    project = Project.find(params[:id])
    authorize_access! :update, :projects, record: project
  end
end
```

The concern provides:

- `current_ability`
- `can_access?(action, resource, record: nil)`
- `authorize_access!(action, resource, record: nil)`
- `current_access_principal`

Override `current_access_principal` in a controller for a local integration, or
use `principal_resolver` for an application-wide rule.

## Handling Denials

Handle the Engine exception at the host boundary appropriate for HTML or JSON:

```ruby
class ApplicationController < ActionController::Base
  rescue_from AnnesAccess::NotAuthorizedError do
    head :forbidden
  end
end
```

Do not rescue all `AnnesAccess::Error` values as an allow or redirect loops may
hide a configuration defect. Log enough action/resource context to diagnose a
denial without logging sensitive record data.
