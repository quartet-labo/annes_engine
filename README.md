# Anne Engine

Anne Engine is a monorepo for reusable Rails engines.

## Gems

- [`anne_auth`](anne_auth/README.md) - account authentication, sessions, verification, password resets, and Google OAuth
- [`anne_access`](anne_access/README.md) - lightweight role-based authorization
- [`anne_admin`](anne_admin/README.md) - configurable administration screens for host models
- [`examples/customer_management`](examples/customer_management/README.md) - sample Rails host app integrating all three engines
- [`examples/resavation_management`](examples/resavation_management/README.md) - reservation workflow sample with RBAC, state transitions, and concurrency control

## Responsibilities

| Engine | Owns | Does not own |
| --- | --- | --- |
| AnneAuth | Login, account sessions, email verification, password resets, Google OAuth | Administrator status, roles, or permissions |
| AnneAccess | Coarse-grained RBAC checks for an authenticated principal | Login, tenant or ownership scopes, or workflow authorization |
| AnneAdmin | Configurable CRUD screens, authentication and authorization hooks, audit notifications | Domain models, credentials, or host-specific business services |

For applications using all three engines, adopt them in this order:

1. Install AnneAuth and decide which account model represents the authenticated principal.
2. Install AnneAccess and define roles, permissions, and assignments for that principal.
3. Install AnneAdmin and connect its authentication and authorization hooks to AnneAuth and AnneAccess.

Each engine can also be used independently when the host application already provides the other responsibilities.

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
  gem "anne_access", "~> 0.1.0"
end
```

For local development from a host application:

```ruby
gem "anne_auth", path: "../anne_engine/anne_auth"
gem "anne_admin", path: "../anne_engine/anne_admin"
gem "anne_access", path: "../anne_engine/anne_access"
```

## Publishing

Publishing is automated by the `Publish Gems` GitHub Actions workflow. The
workflow uses the repository `GITHUB_TOKEN` with `packages: write` permission.

Before publishing, update the target gem's version file, changelog, and upgrade
guide, then commit the release change:

- `anne_auth/lib/anne_auth/version.rb`, `anne_auth/CHANGELOG.md`, and
  `anne_auth/UPGRADING.md`
- `anne_admin/lib/anne_admin/version.rb`, `anne_admin/CHANGELOG.md`, and
  `anne_admin/UPGRADING.md`
- `anne_access/lib/anne_access/version.rb`, `anne_access/CHANGELOG.md`, and
  `anne_access/UPGRADING.md`

See the package-specific upgrade guides before updating a host application:

- [AnneAuth upgrade guide](anne_auth/UPGRADING.md)
- [AnneAccess upgrade guide](anne_access/UPGRADING.md)
- [AnneAdmin upgrade guide](anne_admin/UPGRADING.md)

If a release has no manual host-app upgrade steps, note that explicitly in the
target gem's `UPGRADING.md` instead of leaving the guide ambiguous.

To publish one gem from a release tag, push a gem-specific tag that matches the
gemspec version. The workflow fails if the tag version and gemspec version do
not match. After the gem is published to GitHub Packages, the workflow creates a
GitHub Release for that tag using the target gem's changelog entry.

```sh
git tag anne_auth-v0.3.0
git push origin anne_auth-v0.3.0
```

```sh
git tag anne_admin-v0.2.0
git push origin anne_admin-v0.2.0
```

```sh
git tag anne_access-v0.1.0
git push origin anne_access-v0.1.0
```

You can also run the workflow manually and choose `anne_auth`, `anne_admin`, or
`anne_access`, or `all`. Manual runs publish the version currently defined by
each gemspec, so bump and commit the version first. Manual runs are not
tag-triggered, so they do not create GitHub Releases.

## Sample Apps

### Customer Management

[`examples/customer_management`](examples/customer_management/README.md) is an
internal customer management app. It uses `anne_auth` for staff login,
`anne_access` for RBAC, and `anne_admin` for customer party, person,
organization, customer contact, and project CRUD.

```sh
cd examples/customer_management
bundle install
bin/rails db:setup
bin/rails server
```

Seed account:

- Admin: `admin@example.com` / `password-1234`

### Reservation Management

[`examples/resavation_management`](examples/resavation_management/README.md) is
an internal reservation management app. It combines all three engines with
host-specific daily scheduling, reservation commands, AASM state transitions,
PostgreSQL overlap protection, and optimistic locking.

```sh
cd examples/resavation_management
bundle install
bin/rails db:setup
bin/rails test
bin/rails server
```

Seed accounts use the development-only password `password-1234`:

- Admin: `admin@example.com`
- Operator: `operator@example.com`
- Viewer: `viewer@example.com`

See the reservation management [requirements](examples/resavation_management/docs/requirements.md)
and [design](examples/resavation_management/docs/design.md) for the workflow,
authorization matrix, database constraints, and implementation boundaries.
