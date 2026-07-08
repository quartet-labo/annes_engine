# Changelog

## Unreleased

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
