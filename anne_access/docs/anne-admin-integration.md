# AnneAccess and AnneAdmin Integration

AnneAdmin owns screens and emits an authorization context. AnneAccess can
evaluate that context while the host continues to own authentication and record
visibility.

For role naming and base-app permission matrix examples, see
[Role and permission templates](role-and-permission-templates.md).

## Basic Hook

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

AnneAdmin provides:

| Context key | Value |
| --- | --- |
| `:user` | Result of the AnneAdmin `current_user` hook |
| `:action` | Controller action or registered custom-action name |
| `:resource` | `AnneAdmin::ResourceConfig` |
| `:record` | Loaded member record, or `nil` for collection actions |
| `:controller` | Current AnneAdmin controller |

Make sure `context[:user]` is the same persisted principal type used by
AnneAccess assignments.

## Standard Action Mapping

AnneAccess defaults map AnneAdmin controller actions as follows:

| AnneAdmin action | AnneAccess permission |
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
approve = AnneAccess::Permission.find_or_create_by!(
  resource: "invoices",
  action: "approve"
)
AnneAccess::RolePermission.find_or_create_by!(role: manager, permission: approve)
```

The AnneAdmin action name and permission action must normalize to the same key.
Collection actions receive no record and still require host-owned relation
scoping inside the action block or delegated service.

## Different Authentication and Authorization Principals

An app can authenticate an `AnneAuth::Account` while assigning permissions to a
host `User`. Resolve the host user consistently in AnneAdmin and AnneAccess:

```ruby
AnneAccess.configure do |config|
  config.principal_resolver = ->(controller) {
    controller.send(:current_user)
  }
end

AnneAdmin.configure do |config|
  config.current_user do |controller|
    controller.send(:current_user)
  end
end
```

If AnneAdmin already passes the intended user to `AnneAccess.can?`, the
controller resolver is relevant only to host controllers that include
`AnneAccess::Authorization`.

## Apply Record Scopes

The hook does not change AnneAdmin's base relation. Override the host controller
for tenant-aware resources and define the host route before the Engine mount:

```ruby
class Admin::ProjectsController < AnneAdmin::ResourcesController
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
