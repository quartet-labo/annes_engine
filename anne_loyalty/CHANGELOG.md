# Changelog

## Unreleased

- Add the initial AnneLoyalty engine with program, location, member, ledger,
  point lot, reward, and redemption models.
- Add public services for enrollment, earning, balance reads, FIFO point lot
  consumption, ledger reversal, reward token issuing, and redemption
  confirmation.
- Store redemption token HMAC digests instead of raw tokens and enforce
  one-time token confirmation.
- Add engine tests for model constraints, idempotent earning, reversal,
  insufficient balance, and redemption token edge cases.
