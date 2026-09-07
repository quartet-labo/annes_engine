# Changelog

## Unreleased

## 1.0.1

- Require `json < 3` at runtime to prevent Rails 8.1 JSON decoding errors that
  return HTTP 500 when reading encrypted authentication sessions.

## 1.0.0

- Rename the gem from `anne_auth` to `annes_auth` and the Ruby namespace from
  `AnneAuth` to `AnnesAuth`.
- Rename generated initializer, route, view, notification, and configuration
  identifiers to the `annes_auth` prefix; old require paths and constants are
  not retained as compatibility aliases.
- Add a forward migration that renames `anne_auth_bootstrap_claims` and its
  indexes while preserving existing bootstrap-claim data.

## 0.4.0

- Add an `anne_auth.account_event` notification stream for sign in, sign out,
  password reset, email verification, and invitation lifecycle events.
- Add `AnneAuth::Accounts::BootstrapInvitation` for trusted initial account
  setup through the existing invitation activation flow.
- Add `anne_auth_bootstrap_claims` to keep initial account bootstrap
  idempotent and retryable after delivery failures.
- Add `after_account_bootstrapped` so host apps can attach roles or assignments
  without adding runtime dependencies from AnneAuth to AnnesAccess or AnnesAdmin.
- Document bootstrap setup, event subscription, audit handoff boundaries, and
  MFA/TOTP follow-up scope.

## 0.3.4

- Prevent repeated credential login submissions with a CSP nonce-bearing,
  dependency-free submit guard that is safe across browser history and Turbo
  restoration.
- Ignore framework and submit-button parameters before permitting password login
  credentials so standard form submissions do not emit Strong Parameters warnings.

## 0.3.3

- Limit `Referrer-Policy: no-referrer` to the token-bearing invitation entry
  response so invitation updates remain compatible with Rails origin-based CSRF
  protection.

## 0.3.2

- Add dedicated one-hour account invitation tokens with digest-only storage,
  single-use lookup, resend invalidation, and configurable host model/table
  mapping.
- Add a trusted synchronous invitation delivery API with status-only results and
  multipart account-setup email templates.
- Add a scanner-safe activation flow that removes the plaintext token after the
  entry request and does not consume it until password submission succeeds.
- Atomically set the password, verify the email address, and invalidate all
  outstanding invitation/reset/verification tokens and account sessions without
  automatically signing in the account.
- Filter token parameters, set `Referrer-Policy: no-referrer` on invitation
  responses, and document upstream request-URL log controls.
- Add dedicated configuration, route integration, security/operations, and
  troubleshooting guides, and restructure the README as a complete quick start.

## 0.3.1

- Add configurable account session expiration and secure session cookie options.
- Invalidate active sessions and outstanding reset tokens after password reset.
- Harden authentication, registration, verification, and password reset rate limits.
- Add a configurable minimum password length policy.
- Route unverified password logins to the email verification pending flow.
- Reject disabled Google OAuth callbacks before processing OmniAuth data.

## 0.3.0

- Remove legacy `AdminUser`, `AnneAuth::AdminSession`,
  `AnneAuth::AdminAuthentication`, and Engine admin session routes.
- Remove `--legacy-admin` from the install generator and stop shipping
  `admin_users` / `sessions.admin_user_id` migrations.
- Keep AnneAuth focused on `Account` / `AccountSession`; admin access decisions
  should live in `annes_admin` or host authorization code.
- Existing host databases should drop old `admin_users` / `sessions` tables only
  after confirming they are no longer used by the host app.

## 0.2.2

- Redirect already authenticated verified accounts away from login, signup,
  email verification pending, and admin login through configured host hooks.
  Unverified accounts are sent back to email verification pending.
- Add a configurable email verification completion redirect and return email
  verification POST redirects with `303 See Other`.

## 0.2.1

- Add default authentication views and a neutral `anne_auth` layout for mounted Engine usage.

## 0.2.0

- Keep `Account` / `AccountSession` as the single default authentication principal.
- Default new installs to `accounts` and `account_sessions`; legacy `AdminUser` / `admin_user_id` migrations are available with `--legacy-admin`.
- Keep legacy admin helpers available while host apps migrate admin access checks to host or `annes_admin` authorization.
- Deprecate treating `AdminUser` as the default AnneAuth principal. Admin access should be decided by `annes_admin` or host authorization.

## 0.1.0

- Initial in-repository Rails Engine extraction.
- Prepared gem metadata and package-boundary checks for private git gem extraction.
