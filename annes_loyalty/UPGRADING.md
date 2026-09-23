# Upgrading AnnesLoyalty

AnnesLoyalty is in initial development.

## 1.0.0 -> 1.0.1

Update the gem and run host reward tests. Expired open lots no longer count as
spendable or fund reward redemption before the expiration batch runs. Existing
expired lots and cached balances are unchanged until the host runs its normal
expiration process; check any host displays or reports that use cached balance
directly. Use `balance_for(member:).available_points` for spendable displays
and reward eligibility. No migration is required.

New earn ledger entries record their point-lot ID and expiration date in
metadata. Existing entries need no backfill; reversals without that metadata
prioritize lots using the earning date and the program's current expiration
policy. If the policy changed since an older earning, review its reversal
manually before applying it.

## 0.1.x -> 1.0.0

Replace `anne_loyalty` with `annes_loyalty`, replace `AnneLoyalty` with
`AnnesLoyalty`, run
`bin/rails railties:install:migrations FROM=annes_loyalty`, then run
`bin/rails db:migrate`. The included migration renames all seven loyalty tables
without changing their rows. Back up the host database and update any host
foreign-key/table references before migrating.

## 0.1.0

Initial release. There are no upgrade steps from an earlier published version.

For a first install in a host application:

```sh
bin/rails railties:install:migrations FROM=annes_loyalty
bin/rails db:migrate
```

Add an initializer that sets `token_digest_secret` to a stable application
secret before issuing production redemption tokens. Rotating this secret
invalidates existing unredeemed tokens.
