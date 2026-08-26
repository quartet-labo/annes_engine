# AnnesAccess and AnnesAdmin Integration

AnnesAdmin owns screens and emits an authorization context. AnnesAccess can
evaluate that context while the host continues to own authentication and record
visibility.

For role naming and base-app permission matrix examples, see
[Role and permission templates](role-and-permission-templates.md).

## Basic Hook

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

AnnesAdmin provides:

| Context key | Value |
| --- | --- |
| `:user` | Result of the AnnesAdmin `current_user` hook |
| `:action` | Controller action or registered custom-action name |
| `:resource` | `AnnesAdmin::ResourceConfig` |
| `:record` | Loaded member record, or `nil` for collection actions |
| `:controller` | Current AnnesAdmin controller |

Make sure `context[:user]` is the same persisted principal type used by
AnnesAccess assignments.

## Standard Action Mapping

AnnesAccess defaults map AnnesAdmin controller actions as follows:

| AnnesAdmin action | AnnesAccess permission |
| --- | --- |
| `index`, `show` | `read` |
| `new` | `create` |
| `create` | `create` |
| `edit` | `update` |
| `update` | `update` |
| `destroy` | `destroy` |

A resource `manage` permission covers this standard set.

## Custom Actions

Custom action names are not covered by `manage`. Create an explicit permission:

```ruby
approve = AnnesAccess::Permission.find_or_create_by!(
  resource: "invoices",
  action: "approve"
)
AnnesAccess::RolePermission.find_or_create_by!(role: manager, permission: approve)
```

The AnnesAdmin action name and permission action must normalize to the same key.
Collection actions receive no record and still require host-owned relation
scoping inside the action block or delegated service.

## Different Authentication and Authorization Principals

An app can authenticate an `AnnesAuth::Account` while assigning permissions to a
host `User`. Resolve the host user consistently in AnnesAdmin and AnnesAccess:

```ruby
AnnesAccess.configure do |config|
  config.principal_resolver = ->(controller) {
    controller.send(:current_user)
  }
end

AnnesAdmin.configure do |config|
  config.current_user do |controller|
    controller.send(:current_user)
  end
end
```

If AnnesAdmin already passes the intended user to `AnnesAccess.can?`, the
controller resolver is relevant only to host controllers that include
`AnnesAccess::Authorization`.

## Apply Record Scopes

The hook does not change AnnesAdmin's base relation. Override the host controller
for tenant-aware resources and define the host route before the Engine mount:

```ruby
class Admin::ProjectsController < AnnesAdmin::ResourcesController
  private
    def resource_name
      "projects"
    end

    def resource_scope
      super.where(organization_id: current_account.organization_id)
    end
end
```

Use a matching `custom_rule` or scoped member lookup when member visibility
requires a final check. See [Record scoping](record-scoping.md). The
authorization hook should answer the coarse permission question; it should not
be the only place a tenant-aware app filters records.

## Integration Tests

Cover at least:

- admin role can use each configured standard action;
- viewer can read but cannot create, update, or destroy;
- custom action requires its explicit permission;
- missing/nil principal receives 403;
- cross-tenant records are absent from lists and member actions;
- the resolver returns the assignment principal expected by the seed/backfill.
