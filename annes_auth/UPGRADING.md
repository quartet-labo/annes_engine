# AnnesAuth Upgrade Guide

This guide lists manual steps required when upgrading AnnesAuth in a host
application. Use `CHANGELOG.md` for the full list of code changes; use this file
for actions the host app must perform.

## General Upgrade Checklist

1. Update the host app `Gemfile` version or path.
2. Run `bundle update annes_auth`.
3. Copy any new AnnesAuth migrations into the host app.
   - Preferred: run `bin/rails generate annes_auth:install` and review generated
     / skipped files.
   - Alternative: copy only the missing migration files from `annes_auth/db/migrate`.
4. If the host uses custom table or foreign-key mappings, adapt newly copied
   migrations to that schema before running `bin/rails db:migrate`.
5. Review `config/initializers/annes_auth.rb` for new settings.
6. Run the host app authentication test suite.

If a release has no manual steps, no action is needed beyond updating the gem
and running tests.

## 0.4.x -> 1.0.0

`1.0.0` is a breaking package and namespace rename. Make a database backup
before applying migrations in production.

1. Replace the gem declaration with `gem "annes_auth", "~> 1.0"` and remove
   `anne_auth` from the Gemfile.
2. Replace `require "anne_auth"` with `require "annes_auth"`, and replace all
   `AnneAuth` constants with `AnnesAuth`.
3. Rename host files and overrides that use the old prefix:
   - `config/initializers/anne_auth.rb` -> `config/initializers/annes_auth.rb`
   - `config/routes/anne_auth.rb` -> `config/routes/annes_auth.rb`
   - `app/views/anne_auth` and `app/views/layouts/anne_auth` -> their
     `annes_auth` equivalents
4. Run `bin/rails generate annes_auth:install`, review the copied migration,
   then run `bin/rails db:migrate`. The forward migration renames
   `anne_auth_bootstrap_claims` and its indexes to the `annes_auth` prefix.
   The existing unprefixed account/session/token tables are not renamed.
5. Update notification subscribers from `anne_auth.account_event` to
   `annes_auth.account_event`, then run the full host authentication suite.
   The default verification-code digest salt intentionally remains unchanged so
   unexpired codes issued before the rename can still be verified.

To roll back before application code is deployed, restore the previous gem and
run the migration rollback. Do not roll back after writes have been made through
both application versions without a verified database backup.

## 0.3.4 -> 0.4.0

### Who Is Affected

Host apps that want initial account bootstrap or authentication lifecycle
events should install the new migration and add the new initializer hook. Existing
login, verification, password-reset, OAuth, and invitation flows continue to
work without enabling bootstrap.

### Required Steps

1. Copy and run the bootstrap claim migration:

   ```sh
   bin/rails generate anne_auth:install
   bin/rails db:migrate
   ```

   Confirm that the host has exactly one migration ending in
   `create_anne_auth_bootstrap_claims.rb` and that it creates
   `anne_auth_bootstrap_claims`.

2. Review `config/initializers/anne_auth.rb`. The installer preserves existing
   initializers, so add the hook manually when upgrading:

   ```ruby
   config.after_account_bootstrapped = ->(account) {
     # Host-owned role or assignment setup.
   }
   ```

   Keep role and permission writes in the host app or `anne_access`. AnneAuth
   does not assign administrator status.

3. If the host will persist authentication events, register a subscriber during
   application boot:

   ```ruby
   ActiveSupport::Notifications.subscribe("anne_auth.account_event") do |event|
     AuthEventJob.perform_later(
       event_id: event.transaction_id,
       occurred_at: Time.zone.at(event.time),
       **event.payload.symbolize_keys
     )
   end
   ```

   Review retention and access control for account email, IP address, and user
   agent. Payloads do not include passwords, reset tokens, invitation tokens,
   verification codes, session cookies, or OAuth credentials.

4. To create the first account, call bootstrap from trusted setup code only:

   ```ruby
   result = AnneAuth::Accounts::BootstrapInvitation.call(email: "owner@example.com")
   ```

   Do not expose this call as a public route. The result status is
   `:delivered`, `:already_bootstrapped`, `:invalid_account`, or
   `:delivery_failed`.

### Verification

- A new environment can create exactly one bootstrap account and deliver an
  invitation.
- A `:delivery_failed` result can be retried after fixing mail delivery.
- The bootstrap hook attaches host-owned roles or assignments and rolls back if
  it raises.
- Account event subscribers receive the documented events without credential
  secrets.
- Existing login, logout, verification, password reset, OAuth, and invitation
  tests still pass.

## 0.3.3 -> 0.3.4

### Who Is Affected

Host apps that use the default AnneAuth credential login form get repeated
submission protection automatically. Hosts that override the login view or
AnneAuth layout should review the required steps below.

### Required Steps

1. If the host overrides `anne_auth/accounts/sessions/new`, preserve
   `data-anne-auth-submit-guard` on the credential form.
2. If the host overrides `layouts/anne_auth`, render the submit guard partial:

   ```erb
   <%= render "layouts/anne_auth/submit_guard" %>
   ```

No host DB migration is required.

## 0.3.1 -> 0.3.2

### Who Is Affected

Host apps upgrading to 0.3.2 must install the invitation-token migration before
calling the new invitation delivery API. Existing login, verification, and
password-reset flows do not require invitation data.

### Required Steps

1. Copy the account-invitation-token migration, but do not run it until you
   choose the default or custom mapping path below:

   ```sh
   bin/rails generate anne_auth:install
   ```

   Confirm that the host has exactly one unapplied migration ending in
   `create_anne_auth_account_invitation_tokens.rb`.

2. Choose the migration path that matches the host's existing account mapping:

   **Default mapping (`accounts` / `account_id`):** Run the generated migration
   unchanged:

   ```sh
   bin/rails db:migrate
   ```

   Confirm that it created `account_invitation_tokens` with `account_id`,
   `token_digest`, `expires_at`, and `used_at`.

   **Custom mapping:** Do not run the generated invitation migration unchanged.
   Before `bin/rails db:migrate`, edit that migration or replace it with a host
   migration whose table and reference match `account_invitation_token_table_name`
   and `account_foreign_key`. For example, a host using `customer_accounts` and
   `customer_account_id` needs the equivalent of:

   ```ruby
   create_table :customer_account_invitation_tokens do |t|
     t.references :customer_account,
       null: false,
       foreign_key: { to_table: :customer_accounts },
       index: { name: "idx_customer_invitation_tokens_on_account" }
     t.string :token_digest, null: false
     t.datetime :expires_at, null: false
     t.datetime :used_at
     t.timestamps
   end

   add_index :customer_account_invitation_tokens, :token_digest,
     unique: true, name: "idx_customer_invitation_tokens_on_digest"
   add_index :customer_account_invitation_tokens, :expires_at,
     name: "idx_customer_invitation_tokens_on_expires_at"
   add_index :customer_account_invitation_tokens, :used_at,
     name: "idx_customer_invitation_tokens_on_used_at"
   ```

   Then run `bin/rails db:migrate` and confirm that the custom table and foreign
   key were created. If the default migration was already applied, create a new
   corrective host migration instead of editing migration history.

3. Compare the current initializer template with
   `config/initializers/anne_auth.rb`. The installer preserves an existing
   initializer, so add or confirm these settings manually:

   ```ruby
   config.account_invitation_token_class_name = "AnneAuth::AccountInvitationToken"
   config.account_invitation_token_table_name = "account_invitation_tokens"
   config.account_invitation_url = ->(mailer, token) {
     mailer.account_invitation_url(token: token)
   }
   ```

4. For the custom migration path, create the corresponding invitation-token
   subclass and update all five mapping settings together before AnneAuth models
   load. These values must match the table and reference created in step 2:

   ```ruby
   config.account_class_name = "CustomerAccount"
   config.account_table_name = "customer_accounts"
   config.account_invitation_token_class_name = "CustomerAccountInvitationToken"
   config.account_invitation_token_table_name = "customer_account_invitation_tokens"
   config.account_foreign_key = :customer_account_id
   ```

5. Set production `config.action_mailer.default_url_options` and verify that
   `account_invitation_url` produces an HTTPS URL with the Engine's actual mount
   prefix.

6. Review every reverse proxy, ingress, load balancer, CDN, Cloud Run request
   log, tracing integration, and error reporter that can see the initial
   `/invitation?token=...` URL. Exclude or sanitize query strings where possible;
   otherwise use minimal retention and least-privilege access.

7. Send invitations only from trusted host jobs or management operations:

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
