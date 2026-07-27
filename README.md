# Anne Engine

Anne Engine is a monorepo for reusable Rails engines.

## Project Scope

Anne Engine is the shared foundation used by Quartet Labo LLC. for its
semi-custom web application development services. Development and maintenance of
the project prioritize contracted projects and customers with active support agreements.

The source is published so other teams can inspect, use, and adapt the engines,
but the public project is not operated as a community product with a committed
roadmap or release schedule. The needs of applications developed and maintained
by Quartet Labo LLC. guide the project roadmap.

## Gems

- [`anne_auth`](anne_auth/README.md) - account authentication, sessions, verification, password resets, and Google OAuth
- [`anne_access`](anne_access/README.md) - lightweight role-based authorization
- [`anne_admin`](anne_admin/README.md) - configurable administration screens for host models
- [`anne_loyalty`](anne_loyalty/README.md) - reusable loyalty points, rewards, ledger, and redemption token workflows
- [`examples/customer_management`](examples/customer_management/README.md) - sample Rails host app integrating all three engines
- [`examples/resavation_management`](examples/resavation_management/README.md) - reservation workflow sample with RBAC, state transitions, and concurrency control
- [`examples/restaurant_loyalty`](examples/restaurant_loyalty/README.md) - restaurant point card demo integrating loyalty, auth, access, and admin screens

## Responsibilities

| Engine | Owns | Does not own |
| --- | --- | --- |
| AnneAuth | Login, account sessions, email verification, password resets, Google OAuth | Administrator status, roles, or permissions |
| AnneAccess | Coarse-grained RBAC checks for an authenticated principal | Login, tenant or ownership scopes, or workflow authorization |
| AnneAdmin | Configurable CRUD screens, authentication and authorization hooks, audit notifications | Domain models, credentials, or host-specific business services |
| AnneLoyalty | Loyalty programs, locations, members, append-only point ledger, point lots, rewards, redemptions, and redemption token verification | Customer/POS models, customer-facing screens, staff scan UI, campaign marketing copy, or host RBAC policy |

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
  gem "anne_auth", "~> 0.3.4"
  gem "anne_admin", "~> 0.2.3"
  gem "anne_access", "~> 0.1.2"
  gem "anne_loyalty", "~> 0.1.0"
end
```

For local development from a host application:

```ruby
gem "anne_auth", path: "../anne_engine/anne_auth"
gem "anne_admin", path: "../anne_engine/anne_admin"
gem "anne_access", path: "../anne_engine/anne_access"
gem "anne_loyalty", path: "../anne_engine/anne_loyalty"
```

## Publishing

Publishing is automated by the `Publish Gems` GitHub Actions workflow. The
workflow uses the repository `GITHUB_TOKEN` with `packages: write` permission.

Before publishing, update the target gem's version file, changelog, upgrade
guide, and the dependent sample app lockfiles, then commit the release change:

- `anne_auth/lib/anne_auth/version.rb`, `anne_auth/CHANGELOG.md`, and
  `anne_auth/UPGRADING.md`
- `anne_admin/lib/anne_admin/version.rb`, `anne_admin/CHANGELOG.md`, and
  `anne_admin/UPGRADING.md`
- `anne_access/lib/anne_access/version.rb`, `anne_access/CHANGELOG.md`, and
  `anne_access/UPGRADING.md`
- `anne_loyalty/lib/anne_loyalty/version.rb`, `anne_loyalty/CHANGELOG.md`, and
  `anne_loyalty/UPGRADING.md`

After changing a target gem version, refresh every example app `Gemfile.lock`
that depends on that gem so the path-sourced gemspec version is committed with
the release:

- `anne_auth`: `examples/customer_management/Gemfile.lock`,
  `examples/resavation_management/Gemfile.lock`, and
  `examples/restaurant_loyalty/Gemfile.lock`
- `anne_admin`: `examples/customer_management/Gemfile.lock`,
  `examples/resavation_management/Gemfile.lock`, and
  `examples/restaurant_loyalty/Gemfile.lock`
- `anne_access`: `examples/customer_management/Gemfile.lock`,
  `examples/resavation_management/Gemfile.lock`, and
  `examples/restaurant_loyalty/Gemfile.lock`
- `anne_loyalty`: `examples/restaurant_loyalty/Gemfile.lock`

Run `bundle update <gem_name>` from each affected example directory. For
releases that bump multiple engines together, pass all affected gem names in
the same command for each example app. For example, an AnneAuth release needs:

```sh
(cd examples/customer_management && bundle update anne_auth)
(cd examples/resavation_management && bundle update anne_auth)
(cd examples/restaurant_loyalty && bundle update anne_auth)
```

See the package-specific upgrade guides before updating a host application:

- [AnneAuth upgrade guide](anne_auth/UPGRADING.md)
- [AnneAccess upgrade guide](anne_access/UPGRADING.md)
- [AnneAdmin upgrade guide](anne_admin/UPGRADING.md)
- [AnneLoyalty upgrade guide](anne_loyalty/UPGRADING.md)

If a release has no manual host-app upgrade steps, note that explicitly in the
target gem's `UPGRADING.md` instead of leaving the guide ambiguous.

To publish, run the `Publish Gems` workflow manually through its
`workflow_dispatch` trigger. Select the main ref (`main`), set `gem` to one of
`anne_auth`, `anne_admin`, `anne_access`, or `anne_loyalty`, and set `version`
to the exact gemspec version you intend to publish.

Use one workflow run per gem. For releases that bump multiple engines together,
merge the version, changelog, upgrade guide, and lockfile updates together,
then dispatch the workflow once for each target gem and version.

The workflow verifies that the `version` input matches the target gemspec,
checks that the target `CHANGELOG.md` section exists and is not empty, confirms
that the remote gem-specific tag does not already exist, builds the gem, checks
the packaged MIT license, and publishes to GitHub Packages. After the gem
publish succeeds, the same workflow creates the gem-specific tag and GitHub
Release using the target gem's changelog entry.

Do not push release tags manually as the normal publishing trigger. Tag push
events are not the publishing entrypoint.

If gem publish succeeds but tag or GitHub Release creation fails, first confirm
the package version exists in GitHub Packages. Then create the missing
gem-specific tag on the same commit and create the GitHub Release with notes
from the target gem's changelog entry. Do not rerun the workflow for the same
version until the published package, tag, and release state are reconciled.

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

### Restaurant Loyalty

[`examples/restaurant_loyalty`](examples/restaurant_loyalty/README.md) is a
restaurant point card demo. It uses `anne_loyalty` for the point ledger, reward
exchange, and redemption tokens; `anne_auth` for staff login; `anne_access` for
RBAC; and `anne_admin` for program, location, and reward CRUD.

```sh
cd examples/restaurant_loyalty
bundle install
bin/rails db:setup
bin/rails test
bin/rails server
```

Seed accounts use the development-only password `password-1234`:

- Admin: `admin@example.com`
- Manager: `manager@example.com`
- Staff: `staff@example.com`
- Viewer: `viewer@example.com`

See the restaurant loyalty [README](examples/restaurant_loyalty/README.md) and
[technical concept](examples/restaurant_loyalty/docs/technical_concept.md) for
the demo workflow, MVP boundaries, and future items.

## License

Anne Engine is available under the [MIT License](MIT-LICENSE). The license
permits commercial and non-commercial use, modification, distribution,
sublicensing, and sale, subject to preservation of the copyright and permission
notices.

## Support

Use of the open-source software does not include support, maintenance, bug fixes,
feature development, compatibility guarantees, or release commitments. Paid
implementation, customization, and Standard Support are available separately
from Quartet Labo LLC. See the [support policy](SUPPORT.md) for the boundary
between community use and paid services.

## Contributing

External code contributions are not currently accepted. Issues may be used to
share feedback, but they do not create a response or implementation commitment.
See the [contribution policy](CONTRIBUTING.md) before opening an issue or pull
request.

## Security

Do not disclose suspected vulnerabilities in public issues. Follow the
[security policy](SECURITY.md) to submit a private report.
