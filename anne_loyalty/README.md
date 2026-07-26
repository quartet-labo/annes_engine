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
