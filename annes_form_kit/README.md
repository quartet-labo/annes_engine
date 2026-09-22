# AnnesFormKit

Database-free form schemas, validation, file inspection and Rails field partials.
This is a library, not a Rails Engine. It has no models, migrations, controllers,
routes, global initializer or host authorization callbacks. Annes engines resolve
it transitively; standalone Inquiry users do not add configuration.

## API

```ruby
require "annes_form_kit"
field = AnnesFormKit::FieldSpec.new(key: "name", label: "Name", required: true)
schema = AnnesFormKit::FormSchema.new(title: "Contact", fields: [field])
AnnesFormKit::SchemaValidator.call(schema)
json = AnnesFormKit::SchemaCodec.dump(schema)
copy = AnnesFormKit::SchemaCodec.load(json)
AnnesFormKit::ShapeValidator.call(schema: copy, raw_values: {"name" => "Alice"})
value = AnnesFormKit::ValueConverter.call(field: field, raw: "Alice")
AnnesFormKit::ValueValidator.call(schema: copy, values: {"name" => value})
```

Specs are deeply immutable. Results expose `values`, field-keyed `errors` and
`valid?`. Engines own database mapping, history, authentication, host callbacks,
file persistence and notification delivery. `UploadSource` accepts an IO (or lazy
IO provider) and filename; `AttachmentInspector` validates without persisting.
It returns checksums and sanitized filenames and rewinds inspected IOs.

`Renderer::VIEW_PATH` is explicitly added to each consuming engine's view paths.
The field partials accept schema fields, input/errors, HTML attributes, names,
values and an explicit choice-to-DOM-ID map. They do not create forms or routes.
Consumers retain their own partial entry points to preserve view overrides.

`ValuePresenter.call(field:, value:, time_zone:)` returns ordinary text, never
HTML-safe strings. It uses choice labels and consistently handles missing values,
false, zero, dates and filenames. Views must escape its output.

Schema codec v1 accepts only allowlisted definition properties and supports up to
1 MiB, 200 fields, 2,000 options, 100,000 bytes per string and JSON nesting depth 8.
These limits apply to definition import, not existing database forms.
Import/export do not authorize records; the consuming application must do so.

## Development and publishing

Use Ruby 3.4.9: `bundle install` then `bundle exec rake test`. No database is needed.
From the repository root run `ruby script/check_form_kit_package` to test the built
package. Publish through **Publish Gems** before publishing dependent engines.
See [UPGRADING.md](UPGRADING.md) and [CHANGELOG.md](CHANGELOG.md).
