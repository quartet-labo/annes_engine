# AnneAuth Upgrade Guide

This guide lists manual steps required when upgrading AnneAuth in a host
application. Use `CHANGELOG.md` for the full list of code changes; use this file
for actions the host app must perform.

## General Upgrade Checklist

1. Update the host app `Gemfile` version or path.
2. Run `bundle update anne_auth`.
3. Copy any new AnneAuth migrations into the host app.
   - Preferred: run `bin/rails generate anne_auth:install` and review generated
     / skipped files.
   - Alternative: copy only the missing migration files from `anne_auth/db/migrate`.
4. Run `bin/rails db:migrate`.
5. Review `config/initializers/anne_auth.rb` for new settings.
6. Run the host app authentication test suite.

If a release has no manual steps, no action is needed beyond updating the gem
and running tests.

## 0.3.1 -> 0.3.2

### Who Is Affected

Host apps upgrading to 0.3.2 must install the invitation-token migration before
calling the new invitation delivery API. Existing login, verification, and
password-reset flows do not require invitation data.

### Required Steps

1. Copy and run the account-invitation-token migration:

   ```sh
   bin/rails generate anne_auth:install
   bin/rails db:migrate
   ```

   Confirm that the host has exactly one migration ending in
   `create_anne_auth_account_invitation_tokens.rb` and an
   `account_invitation_tokens` table with `account_id`, `token_digest`,
   `expires_at`, and `used_at`.

2. Compare the current initializer template with
   `config/initializers/anne_auth.rb`. The installer preserves an existing
   initializer, so add or confirm these settings manually:

   ```ruby
   config.account_invitation_token_class_name = "AnneAuth::AccountInvitationToken"
   config.account_invitation_token_table_name = "account_invitation_tokens"
   config.account_invitation_url = ->(mailer, token) {
     mailer.account_invitation_url(token: token)
   }
   ```

3. If the host maps accounts to custom classes/tables, create the corresponding
   invitation-token subclass/table and make its foreign key match
   `account_foreign_key`. Update all four mapping settings together:

   ```ruby
   config.account_class_name = "CustomerAccount"
   config.account_invitation_token_class_name = "CustomerAccountInvitationToken"
   config.account_invitation_token_table_name = "customer_account_invitation_tokens"
   config.account_foreign_key = :customer_account_id
   ```

4. Set production `config.action_mailer.default_url_options` and verify that
   `account_invitation_url` produces an HTTPS URL with the Engine's actual mount
   prefix.

5. Review every reverse proxy, ingress, load balancer, CDN, Cloud Run request
   log, tracing integration, and error reporter that can see the initial
   `/invitation?token=...` URL. Exclude or sanitize query strings where possible;
   otherwise use minimal retention and least-privilege access.

6. Send invitations only from trusted host jobs or management operations:

   ```ruby
   result = AnneAuth::Accounts::InvitationDelivery.call(account)
   # result.status is :delivered, :invalid_account, or :delivery_failed
   ```

### Verification

- An invitation email contains the expected HTTPS activation URL and expires in
  one hour.
- Opening the link redirects to a URL without the token and does not consume the
  invitation.
- A validation error can be corrected with the same invitation session.
- Successful activation redirects to login without authenticating the account
  and invalidates its existing tokens and sessions.
- Resending makes the previous invitation URL unusable.
- Application and upstream request logs do not retain plaintext invitation
  tokens.

## 0.3.0 -> 0.3.1

### Who Is Affected

Host apps using `AnneAuth::AccountSession` or the default `account_sessions`
table.

### Required Steps

1. Copy and run the account-session expiration migration:

   ```sh
   bin/rails generate anne_auth:install
   bin/rails db:migrate
   ```

2. Ensure the host app `account_sessions` table has:

   - `expires_at`, `datetime`, `null: false`
   - `last_used_at`, `datetime`
   - an index on `expires_at`

3. Review session cookie settings in `config/initializers/anne_auth.rb` if the
   host app needs custom TTL or secure-cookie behavior:

   ```ruby
   config.account_session_expires_in = 2.weeks
   config.account_session_cookie_secure = ->(request) { request.ssl? || Rails.env.production? }
   ```

### Data Migration

The expiration migration backfills existing `account_sessions.expires_at` with a
two-week expiry and sets `last_used_at` from existing timestamps when possible.

### Verification

- Existing users can log in.
- Existing sessions without `expires_at` do not raise missing attribute errors.
- Expired sessions are rejected and cleaned up.
- Password reset invalidates existing sessions.

## 0.2.x -> 0.3.0

### Who Is Affected

Host apps that still depend on legacy admin authentication classes or tables:

- `AdminUser`
- `AnneAuth::AdminSession`
- `AnneAuth::AdminAuthentication`
- `admin_users`
- `sessions.admin_user_id`
- `current_admin_user`
- `admin_session_id`

### Required Steps

1. Move admin access decisions to `anne_admin` or host authorization code.
2. Use `Account` / `AccountSession` as the AnneAuth authentication principal.
3. Remove references to legacy admin helpers from controllers, views, tests, and
   initializers.
4. If the host app no longer uses `admin_users` or legacy `sessions`, create a
   host migration to drop or archive those tables after confirming no production
   data is needed.

### Verification

- Account login and logout still work.
- Admin pages are protected by `anne_admin` or host authorization.
- No runtime code references `AdminUser`, `current_admin_user`, or
  `admin_session_id`.
