# Upgrading AnnesLoyalty

AnnesLoyalty is in initial development.

## 0.1.x -> 1.0.0

Replace `anne_loyalty` with `annes_loyalty`, replace `AnneLoyalty` with
`AnnesLoyalty`, and run `bin/rails db:migrate`. The included migration renames
all seven loyalty tables without changing their rows. Back up the host database
and update any host foreign-key/table references before migrating.

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
