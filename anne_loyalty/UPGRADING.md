# Upgrading AnneLoyalty

AnneLoyalty is in initial development.

## 0.1.0

Initial release. There are no upgrade steps from an earlier published version.

For a first install in a host application:

```sh
bin/rails railties:install:migrations FROM=anne_loyalty
bin/rails db:migrate
```

Add an initializer that sets `token_digest_secret` to a stable application
secret before issuing production redemption tokens. Rotating this secret
invalidates existing unredeemed tokens.
