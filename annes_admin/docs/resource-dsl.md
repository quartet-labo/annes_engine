# AnnesAdmin Resource DSL

Define one host model per resource file. AnnesAdmin loads Ruby files under
`app/admin/resources/**/*.rb` and `config/annes_admin/resources/**/*.rb` in
sorted path order.

```ruby
# app/admin/resources/01_projects.rb
AnnesAdmin.resource :projects, model: "Project", destroyable: true do
  label "Projects"
  includes :customer
  field :name, searchable: true, sortable: true
  field :status, type: :enum, collection: Project::STATUS_LABELS
  field :customer_id,
    type: :association,
    collection: -> { Customer.order(:name) },
    display_with: ->(project) { project.customer&.name }
  field :updated_at, type: :datetime, permitted: false, sortable: true
  permitted_attributes :name, :status, :customer_id
end
```

Each resource key can be registered only once. Duplicate definitions raise
`AnnesAdmin::ConfigurationError`. Prefix filenames when navigation order matters.

## Resource Options

| Option | Required/default | Effect |
| --- | --- | --- |
| `model` | required | Host model constant name resolved when the resource is used. |
| `label` | model plural label | Navigation and page label. Can also be set with the block DSL. |
| `actions` | `index show new create edit update` | Allowed controller actions for the resource. |
| `destroyable` | `false` | Adds or removes `destroy` from allowed actions. |

Restrict a resource to a read-only surface:

```ruby
AnnesAdmin.resource :audit_entries, model: "AuditEntry" do
  actions :index, :show
end
```

The default templates currently expose navigation for index/show, new/edit,
and member custom actions. A configured destroy or collection custom action may
need a host view/button even though its Engine route and controller action
exist.

## Fields

`field` replaces an earlier field with the same name and preserves declaration
order for display and forms.

| Type | Display/input behavior |
| --- | --- |
| `string` | Text display and `text_field` |
| `text` | Text display and four-row `text_area` |
| `integer`, `decimal`, `number` | Text display and `number_field` |
| `boolean` | `Yes`/`No` display and checkbox |
| `date`, `datetime` | Default Rails formatted display and `date_field` |
| `enum` | Label lookup and select |
| `association` | Associated label display and select |

Unknown types raise `AnnesAdmin::ConfigurationError` while loading the resource.

### Common Field Options

| Option | Default | Effect |
| --- | --- | --- |
| `label` | humanized field name | Column/form label. |
| `searchable` | `false` | Adds the field to the search allowlist. Only string/text database columns are searched. |
| `sortable` | `false` | Adds the field to the sort allowlist. The name must also be a real model column. |
| `permitted` | `true` | Includes the field in forms and inferred writable attributes. |
| `readonly` | `false` | Excludes the field from forms and writes even when `permitted` is true. |
| `display_with` | none | Callable receiving the record; its result is used for display. |
| `collection` | none | Hash, array, relation, or callable used to build select options. |

Use `permitted: false` or `readonly: true` for IDs, timestamps, calculated
values, secrets, and other display-only fields.

### Enum Collections

Use a value-to-label hash:

```ruby
field :status,
  type: :enum,
  collection: { "draft" => "Draft", "published" => "Published" }
```

A callable is evaluated when the field is rendered. Keep it bounded and avoid a
database query per record.

### Association Collections

A collection may return records, `[label, value]` arrays, or a value-to-label
hash. Records use `display_name`, `name`, `title`, or their string value for the
select label, in that order.

For a foreign-key field, use `display_with` to render the associated object on
index/show pages. `label_method` is used by an association field when the value
read from the record is itself an associated object.

```ruby
field :customer_id,
  type: :association,
  collection: -> { Customer.order(:name) },
  display_with: ->(project) { project.customer&.display_name }
```

## Writable Attributes

Only `permitted_attributes` can pass through create/update strong parameters:

```ruby
permitted_attributes :name, :status, :customer_id
```

When omitted, AnnesAdmin infers the list from permitted, non-readonly fields.
Prefer an explicit list for security-sensitive resources. Adding a field to the
index does not require making it writable.

## Search and Sort Allowlists

Field options normally define the allowlists, but they can be extended directly:

```ruby
searchable_by :name, :reference
sortable_by :name, :updated_at
```

Search escapes SQL wildcard input and applies `LIKE` conditions only to real
string/text columns. Sort ignores unknown/non-column attributes and accepts
only `asc` or `desc` direction, defaulting to ascending.

## Includes and Scopes

Preload associations used by display callables:

```ruby
includes :customer, :owner
```

Named filters receive the current relation:

```ruby
scope :active, label: "Active" do |relation|
  relation.where(archived_at: nil)
end
```

If no block is supplied and the relation responds to the scope name, AnnesAdmin
calls that relation scope. An unknown `params[:scope]` leaves the relation
unchanged. Scopes do not replace host-owned tenant/ownership filtering; apply
that in a host controller's `resource_scope`.

## Custom Actions

```ruby
AnnesAdmin.resource :projects, model: "Project" do
  custom_action :archive,
    method: :post,
    scope: :member,
    label: "Archive",
    confirm: "Archive this project?" do |record:, controller:, resource:|
      record.update!(archived_at: Time.current)
  end
end
```

| Option | Default | Notes |
| --- | --- | --- |
| `method` | `:post` | Must match the request method; otherwise the Engine returns 405. |
| `scope` | `:member` | `:member` receives a record; `:collection` receives `record: nil`. |
| `label` | humanized action name | Button and success-message text. |
| `confirm` | `nil` | Turbo confirmation text used by the default member-action button. |

The block receives `record`, `controller`, and `resource` keyword arguments.
It may redirect or render through the controller. If it does not complete the
response, AnnesAdmin redirects to the member show or collection index page.

Prefer delegation to a host service for transactions, external calls, and
business workflows. AnnesAdmin authorizes by custom action name; when using
AnnesAccess, create a matching explicit permission because `manage` covers only
standard actions.

## Additional Resource Paths

```ruby
AnnesAdmin.configure do |config|
  config.resource_paths << Rails.root.join("config/annes_admin/custom_resources")
end
```

Default paths load first, followed by configured paths. Avoid registering the
same key in multiple locations.
