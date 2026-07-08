# Changelog

## Unreleased

- Add generic `User` / `AnneAuth::Session` authentication primitives and `current_user` / `require_authentication` controller helpers.
- Default new installs to `users` and `sessions.user_id`; legacy `AdminUser` / `admin_user_id` migrations are available with `--legacy-admin`.
- Keep legacy admin helpers as wrappers around the generic user session flow while host apps migrate.
- Deprecate treating `AdminUser` as the default AnneAuth principal. Admin access should be decided by `anne_admin` or host authorization.

## 0.1.0

- Initial in-repository Rails Engine extraction.
- Prepared gem metadata and package-boundary checks for private git gem extraction.
