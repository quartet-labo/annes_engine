# AnneLoyalty

AnneLoyalty is a Rails engine for reusable loyalty points, rewards, and redemption workflows.

The engine owns point consistency: programs, locations, members, append-only ledger entries, point lots, rewards, redemptions, idempotency, and redemption token verification. Host applications own industry-specific workflows and screens, and should call `AnneLoyalty.*` service APIs instead of directly mutating engine records.

## Requirements

- Ruby 3.4 or newer
- Rails 8.1
- PostgreSQL

## Local Development

```sh
bundle install
bundle exec rake test
```

## Documentation

- [Security and operations](docs/security-and-operations.md)
- [Upgrade guide](UPGRADING.md)

## Quick Start

Add the engine to the host app:

```ruby
source "https://rubygems.org"

source "https://rubygems.pkg.github.com/quartet-labo" do
  gem "anne_loyalty", "~> 0.1.0"
end
```

For local development from this monorepo, use a path source:

```ruby
gem "anne_loyalty", path: "../anne_engine/anne_loyalty"
```

Install the engine migrations and migrate the host database:

```sh
bin/rails railties:install:migrations FROM=anne_loyalty
bin/rails db:migrate
```

Set the token digest secret in an initializer. Use a stable production secret;
changing it invalidates existing unredeemed tokens.

```ruby
# config/initializers/anne_loyalty.rb
AnneLoyalty.configure do |config|
  config.token_digest_secret = Rails.application.secret_key_base
end
```

Connect host customers or members through a polymorphic owner:

```ruby
class Customer < ApplicationRecord
  has_one :loyalty_member,
    class_name: "AnneLoyalty::LoyaltyMember",
    as: :owner,
    dependent: :restrict_with_exception
end
```

## Public API

The host-facing API is intentionally exposed from the top-level module.

```ruby
AnneLoyalty.enroll!(program:, owner:, member_key:)
AnneLoyalty.quote_earn(member:, location:, amount_cents:, occurred_at: Time.current, context: {})
AnneLoyalty.earn!(member:, location:, amount_cents:, source:, occurred_at: Time.current, actor: nil)
AnneLoyalty.balance_for(member:)
AnneLoyalty.redeem_reward!(member:, reward:, actor: nil)
AnneLoyalty.confirm_redemption!(token:, location:, actor: nil)
AnneLoyalty.reverse!(ledger_entry:, reason:, actor: nil)
```

These APIs are implemented by command services under `app/services/anne_loyalty`.

## Data Model

AnneLoyalty stores reusable loyalty primitives under `anne_loyalty_loyalty_*`
tables:

- `LoyaltyProgram`: earning rate, point name, expiration months, active state
- `LoyaltyLocation`: program-scoped store or operating location
- `LoyaltyMember`: program enrollment for a polymorphic host owner
- `LoyaltyLedgerEntry`: append-only point facts with source idempotency keys
- `LoyaltyPointLot`: FIFO consumable point lots for expiration-aware balances
- `LoyaltyReward`: exchangeable reward definitions
- `LoyaltyRedemption`: short-lived reward token state and redemption audit data

Host applications should keep customer, receipt, POS, notification, and screen
logic outside the engine.

## Behavior Notes

- `earn!` locks the member, writes one ledger entry, creates one point lot, and
  updates cached balance in a transaction.
- `source_type` and `source_key` make earning idempotent for receipts or
  external events.
- `redeem_reward!` issues a raw token once and stores only its HMAC digest.
- `confirm_redemption!` validates token status, expiry, location, and balance
  before writing the redeem ledger entry.
- `reverse!` adds a reverse ledger entry instead of mutating the original entry.

## Demo App

See [`examples/restaurant_loyalty`](../examples/restaurant_loyalty/README.md)
for a runnable host app with customer pages, staff point workflows, AnneAdmin
resources, RBAC seed data, and acceptance tests.

## Release Workflow

The distribution target is GitHub Packages. Use this flow for releases:

1. Run the engine test suite from the engine repository with `bundle exec rake test`.
2. Update `lib/anne_loyalty/version.rb` to the version you want to publish.
3. Update `CHANGELOG.md` and `UPGRADING.md` for that version.
4. Update the dependent example app lockfile by running `bundle update anne_loyalty`
   from `examples/restaurant_loyalty`.
5. Commit the release, including the changed example `Gemfile.lock` file.
6. Run the `Publish Gems` workflow with the `workflow_dispatch` trigger,
   selecting the `main` ref, `gem` = `anne_loyalty`, and `version` equal to
   `AnneLoyalty::VERSION`.
7. Confirm the workflow published the package to GitHub Packages and creates
   the gem-specific tag and GitHub Release for that version.
8. Update host applications with `bundle update anne_loyalty` and run their full test suites.

The workflow fails before publishing if the `version` input does not match
`AnneLoyalty::VERSION`, the changelog section is missing or empty, or the remote
gem-specific tag already exists. Tag push events are not the release entrypoint.
