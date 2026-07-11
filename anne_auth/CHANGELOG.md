# Changelog

## Unreleased

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
  should live in `anne_admin` or host authorization code.
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
- Keep legacy admin helpers available while host apps migrate admin access checks to host or `anne_admin` authorization.
- Deprecate treating `AdminUser` as the default AnneAuth principal. Admin access should be decided by `anne_admin` or host authorization.

## 0.1.0

- Initial in-repository Rails Engine extraction.
- Prepared gem metadata and package-boundary checks for private git gem extraction.
