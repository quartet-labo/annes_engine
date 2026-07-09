# Anne Engine

Anne Engine is a monorepo for reusable Rails engines.

## Gems

- `anne_auth`
- `anne_admin`
- `examples/customer_management` - sample Rails host app using both engines

## Installation

Anne Engine gems are distributed through GitHub Packages.

Configure Bundler credentials in each host application environment. Use a token
with `read:packages` access for installs.

```sh
bundle config https://rubygems.pkg.github.com/quartet-labo GITHUB_USERNAME:GITHUB_PACKAGES_TOKEN
```

Add the GitHub Packages source to the host application's `Gemfile`.

```ruby
source "https://rubygems.org"

source "https://rubygems.pkg.github.com/quartet-labo" do
  gem "anne_auth", "~> 0.3.0"
  gem "anne_admin", "~> 0.2.0"
end
```

For local development from a host application:

```ruby
gem "anne_auth", path: "../anne_engine/anne_auth"
gem "anne_admin", path: "../anne_engine/anne_admin"
```

## Publishing

Publishing is automated by the `Publish Gems` GitHub Actions workflow. The
workflow uses the repository `GITHUB_TOKEN` with `packages: write` permission.

To publish one gem from a release tag, push a gem-specific tag that matches the
gemspec version:

```sh
git tag anne_auth-v0.3.0
git push origin anne_auth-v0.3.0
```

```sh
git tag anne_admin-v0.2.0
git push origin anne_admin-v0.2.0
```

You can also run the workflow manually and choose `anne_auth`, `anne_admin`, or
`all`.

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

- Admin: `admin@example.com` / `password-1234`
