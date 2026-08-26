# AnnesAccess RBAC Setup

AnnesAccess stores a normalized, host-defined permission matrix. Authentication
must already provide a persisted principal such as an account or user.

For reusable starting points across semi-order base apps, see
[Role and permission templates](role-and-permission-templates.md). Keep those
templates host-adjusted; AnnesAccess does not enforce special behavior for role
names such as `manager`, `operator`, `customer`, or `member`.

## Data Model

```text
principal --< assignment >-- role --< role_permission >-- permission
```

| Model | Purpose | Important constraints |
| --- | --- | --- |
| `AnnesAccess::Role` | Named set of permissions | `key` is unique, lowercase, and limited to letters, digits, and underscores; `name` is required |
| `AnnesAccess::Permission` | One resource/action pair | `resource` and `action` are normalized to lowercase; the pair and generated `key` are unique |
| `AnnesAccess::RolePermission` | Connects a role to a permission | A permission can be connected to a role only once |
| `AnnesAccess::Assignment` | Connects a polymorphic principal to a role | A principal can receive the same role only once |

The four Engine migrations create `annes_access_roles`,
`annes_access_permissions`, `annes_access_role_permissions`, and
`annes_access_assignments`. The host owns the rows and their lifecycle.

## Choose Resource and Action Names

Use stable plural resource keys that match the name passed by controllers and
AnneAdmin, for example `customers`, `projects`, and `invoices`.

Standard actions are:

- `read`
- `create`
- `update`
- `destroy`
- `manage`

Controller actions `index` and `show` map to `read`, `new` maps to `create`, and
`edit` maps to `update`. `manage` grants all standard actions for the same
resource. It does not grant arbitrary custom actions such as `approve`.

Create explicit custom-action permissions when the host needs them:

```ruby
AnnesAccess::Permission.find_or_create_by!(
  resource: "invoices",
  action: "approve"
)
```

## Idempotent Seed

The install generator creates `db/seeds/annes_access.rb`. Adapt its
`role_permissions` matrix to the host's resource list and keep it safe to run
more than once:

```ruby
role_permissions = {
  "admin" => {
    name: "Admin",
    resources: {
      "customers" => %w[manage],
      "projects" => %w[manage]
    }
  },
  "viewer" => {
    name: "Viewer",
    resources: {
      "customers" => %w[read],
      "projects" => %w[read]
    }
  }
}

role_permissions.each do |role_key, definition|
  role = AnnesAccess::Role.find_or_initialize_by(key: role_key)
  role.update!(name: definition.fetch(:name), system: true)

  definition.fetch(:resources).each do |resource, actions|
    actions.each do |action|
      permission = AnnesAccess::Permission.find_or_create_by!(resource:, action:)
      AnnesAccess::RolePermission.find_or_create_by!(role:, permission:)
    end
  end
end
```

The generated file is not loaded automatically by Rails. Reference it from the
host seed entrypoint:

```ruby
# db/seeds.rb
load Rails.root.join("db/seeds/annes_access.rb")
```

```sh
bin/rails db:seed
```

Do not delete permission rows merely because they disappear from the current
seed list. Treat removal as an explicit data migration after confirming no
role or audit process still depends on the key.

## Assign Roles

Assignments require a persisted principal with an ID:

```ruby
account = Account.find_by!(email: "admin@example.com")
admin = AnnesAccess::Role.find_by!(key: "admin")

AnnesAccess::Assignment.find_or_create_by!(principal: account, role: admin)
```

The polymorphic association records both principal class and ID. Renaming a
principal class requires a data migration for `principal_type` values.

## Verify Allow and Deny

Check positive and negative cases in a console after seeding:

```ruby
AnnesAccess.can?(account, :index, :customers)   # admin customers.manage => true
AnnesAccess.can?(account, :destroy, :projects) # admin projects.manage => true
AnnesAccess.can?(nil, :read, :customers)       # => false
AnnesAccess.can?(account, :read, :unknown)     # => false
```

Add request tests around protected endpoints. A permission data test alone does
not prove the controller selected the correct principal, resource key, action,
or host-owned record scope.

## Adopting AnnesAccess in an Existing Host

When a host already has `accounts.role` or ad hoc role checks:

1. Inventory every existing role value and protected operation.
2. Define the target AnnesAccess role/permission matrix.
3. Install and migrate the four tables.
4. Seed roles, permissions, and role-permission links.
5. Backfill assignments with a migration or one-off rake task.
6. Compare old and new allow/deny behavior in tests.
7. Switch controller and AnneAdmin checks.
8. Remove the legacy role column only in a later, separately verified migration.

Do not rely on `db:seed` to backfill existing production principals. Seeds are
appropriate for reference data, while a migration or versioned task provides
an auditable, deploy-safe backfill.

Example backfill shape:

```ruby
admin = AnnesAccess::Role.find_by!(key: "admin")

Account.where(role: "admin").find_each do |account|
  AnnesAccess::Assignment.find_or_create_by!(principal: account, role: admin)
end
```

Run it inside the host's deployment and rollback strategy. Verify counts and
sample principals before removing legacy checks.
