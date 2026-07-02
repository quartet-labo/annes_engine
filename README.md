# Anne Engine

Anne Engine is a monorepo for reusable Rails engines.

## Gems

- `anne_auth`
- `anne_admin`
- `examples/customer_management` - sample Rails host app using both engines

## Installation

```ruby
git "git@github.com:quartet-labo/anne_engine.git", tag: "v0.1.0" do
  gem "anne_auth"
  gem "anne_admin"
end
```

For local development from a host application:

```sh
bundle config set local.anne_auth ../anne_engine
bundle config set local.anne_admin ../anne_engine
```

## Sample App

`examples/customer_management` contains a simple internal customer management
app that uses `anne_auth` for staff admin login and `anne_admin` for customer
party, person, organization, customer contact, and project CRUD. The sample
supports both individual and organization customers through a shared customer
ledger.

```sh
cd examples/customer_management
bundle install
bin/rails db:setup
bin/rails server
```

Seed users:

- Admin: `admin@example.com` / `password`
