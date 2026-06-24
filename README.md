# Anne Engine

Anne Engine is a monorepo for reusable Rails engines.

## Gems

- `anne_auth`
- `anne_admin`

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
