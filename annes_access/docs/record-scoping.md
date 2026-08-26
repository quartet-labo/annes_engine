# AnnesAccess Record Scoping

AnnesAccess answers whether a principal has an action for a resource. It does not
build an Active Record relation for ownership, tenant membership, customer
visibility, or workflow state.

Use [Role and permission templates](role-and-permission-templates.md) for the
coarse permission matrix, then apply host-owned scopes in the app code that
loads records.

## Collection Actions

For an index action there is normally no record. Apply host-owned scopes before
pagination, rendering, export, or background processing:

```ruby
def index
  authorize_access! :index, :projects
  @projects = Project.visible_to(current_account).order(updated_at: :desc)
end
```

RBAC permission to read `projects` does not imply permission to read every
project row. Never start from `Project.all` in a tenant-aware host merely
because `AnnesAccess.can?` returned true.

Centralize the relation rule so the same scope can be reused by index, search,
export, autocomplete, counters, and jobs:

```ruby
class Project < ApplicationRecord
  scope :visible_to, ->(principal) {
    where(organization_id: principal.organization_id)
  }
end
```

## Member Actions

Load a member through the same scoped relation, then authorize the coarse
action:

```ruby
def update
  @project = Project.visible_to(current_account).find(params[:id])
  authorize_access! :update, :projects, record: @project
  @project.update!(project_params)
end
```

Scoped loading avoids revealing whether an out-of-scope record exists. Passing
the record allows a custom rule to enforce an additional state or ownership
condition, but does not replace scoped loading.

## Custom Record Rules

```ruby
AnnesAccess.configure do |config|
  config.custom_rule = ->(principal:, action:, resource:, record:, allowed:) {
    return false unless allowed
    return true unless resource == "projects" && record

    Project.visible_to(principal).where(id: record.id).exists?
  }
end
```

The custom rule receives `allowed`, the coarse role result. Its own return value
is final, so preserve false unless the host deliberately defines an alternate
grant rule. Keep queries bounded by indexed columns and avoid loading
associations one record at a time in a list.

For collection actions `record` is `nil`; the rule cannot return a filtered
relation. AnnesAccess intentionally has no `accessible_by` equivalent.

## Tenant and Ownership Checklist

Apply the host scope consistently to:

- index and search results;
- show, edit, update, and destroy lookups;
- CSV or file export;
- association selectors and autocomplete;
- dashboard counts and summaries;
- background jobs and service objects;
- custom AnnesAdmin actions.

Test two tenants or owners, not just an authorized and unauthorized role. A
useful matrix includes same-tenant allowed, same-tenant denied action,
cross-tenant denied, missing assignment, and nil principal. See
[Role and permission templates](role-and-permission-templates.md) for tenant,
owner, assignee, and membership relation patterns.
