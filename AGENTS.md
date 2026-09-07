# Agent Guide

This repository is a monorepo for reusable Rails engines maintained as the
shared foundation for Quartet Labo LLC. semi-custom web application projects.

## Repository Layout

- `annes_auth/`: authentication, sessions, verification, password resets,
  invitations, bootstrap, event hooks, and Google OAuth.
- `annes_access/`: lightweight role-based authorization.
- `annes_admin/`: configurable administration screens for host models.
- `annes_inquiry/`: configurable inquiry forms, typed answers, administration, and host adapters.
- `annes_loyalty/`: loyalty programs, members, point ledger, rewards, and
  redemption workflows.
- `examples/`: Rails host applications that demonstrate engine integration.
- `script/` and `test/`: repository-level CI, documentation, release, and
  compliance helpers.

## Working Rules

- Keep engine responsibilities separate. Do not move authentication concerns
  into access/admin/loyalty code, or host-application business rules into an
  engine.
- Prefer changes scoped to the affected engine and its relevant example apps.
- Update the affected engine's `README.md`, `CHANGELOG.md`, and `UPGRADING.md`
  when behavior, public APIs, installation steps, or release notes change.
- Keep generated gem files and build artifacts out of normal feature changes
  unless the task is explicitly about packaging or release validation.
- Preserve the public-project policy in `CONTRIBUTING.md`: this repository is
  published for inspection and use, but external pull requests are not accepted
  unless explicitly requested by a maintainer.

## Validation

Use Ruby 3.4.9, matching CI.

- Engine tests:
  - `cd annes_auth && bundle exec rake test`
  - `cd annes_admin && bundle exec rake test`
  - `cd annes_access && bundle exec rake test`
  - `cd annes_loyalty && bundle exec rake test`
- Inquiry engine tests (dedicated PostgreSQL DB):
  - `cd annes_inquiry && bin/test --prepare && bundle exec rake test`
  - `cd annes_inquiry && bin/test --schema-round-trip && bin/test --system`
- Example app tests:
  - `cd examples/customer_management && bin/rails test`
  - `cd examples/resavation_management && bin/rails test`
  - `cd examples/restaurant_loyalty && bin/rails test`
- Documentation and repository checks:
  - `ruby test/documentation_checker_test.rb`
  - `ruby test/public_project_policy_test.rb`
  - `ruby test/mit_license_compliance_test.rb`
  - `ruby script/check_docs`

CI selects component tests from changed paths with `script/select_ci_targets`.
Run the narrowest relevant test command locally, and broaden to dependent
example apps when an engine integration contract changes.

## Versioning Rules

Manage each gem version with `MAJOR.MINOR.PATCH`.

- Increment `MAJOR` for incompatible public API changes, behavior changes that
  require host applications to change existing integration code, removed
  features, or migration changes that require manual data or deployment steps.
- Increment `MINOR` for backward-compatible features, new configuration
  options, new generators, new routes, or additive database changes.
- Increment `PATCH` for backward-compatible bug fixes, security fixes,
  documentation corrections tied to a release, or internal maintenance that does
  not change the host application's integration contract.

When a version changes, update the target engine's version constant in
`lib/<engine>/version.rb`, the changelog, the upgrade guide, and any dependent
example app lockfiles. Do not change a gem version for documentation-only work
unless maintainers intend to publish a package for that documentation update.

## Releases

Gem publishing is handled by the `Publish Gems` GitHub Actions workflow. For a
release change, update the target engine version, changelog, upgrade guide, and
dependent example app lockfiles. Do not push release tags manually as the normal
publishing trigger.
