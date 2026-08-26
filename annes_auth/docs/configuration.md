# AnnesAuth Configuration

Configure AnnesAuth in `config/initializers/annes_auth.rb`. Settings are process
global and should be assigned during application boot.

```ruby
AnnesAuth.configure do |config|
  config.mailer_from = "accounts@example.com"
  config.account_password_minimum_length = 12
  config.account_session_expires_in = 2.weeks
  config.after_account_login_path = ->(controller, _account) {
    controller.main_app.root_path
  }
end
```

## Common Settings

| Setting | Default | Contract and effect |
| --- | --- | --- |
| `mailer_from` | `"noreply@example.com"` | Sender passed to the account mailer. Replace it in every production host. |
| `account_mailer_class_name` | `"AnnesAuth::AccountMailer"` | Constant name used for verification, password-reset, and invitation messages. |
| `account_email_format` | `URI::MailTo::EMAIL_REGEXP` | Regular expression used by the account email validation. |
| `account_password_minimum_length` | `12` | Minimum length enforced on account creation and password reset. |
| `account_session_cookie_name` | `:account_session_id` | Name of the signed session cookie. |
| `account_session_expires_in` | `2.weeks` | Duration used for both the database session expiry and signed cookie expiry. Must respond to `from_now`. |
| `account_session_cookie_secure` | `->(request) { request.ssl? || Rails.env.production? }` | Boolean or callable receiving the request. Controls the cookie `secure` flag. |
| `bootstrap_claim_table_name` | `"annes_auth_bootstrap_claims"` | Table used by `BootstrapInvitation` to make initial account setup one-time and retryable. Configure before `AnnesAuth::BootstrapClaim` loads. |

Session cookies are also `httponly: true` and `same_site: :lax`. See
[Security and operations](security-and-operations.md) before changing their
lifetime or secure behavior.

## Redirect and Lifecycle Hooks

| Setting | Callable arguments | Default | Used for |
| --- | --- | --- | --- |
| `after_account_login_path` | `(controller, account)` | `controller.main_app.root_path` | Successful verified login and redirecting an already authenticated account away from entry pages. |
| `after_account_email_verification_path` | `(controller, account)` | `controller.main_app.root_path` | Successful email-code verification. |
| `after_account_profile_completion_path` | `(controller, account)` | `controller.main_app.root_path` | Returning after a required host-owned profile is completed. |
| `account_profile_path` | `(controller, account)` | `controller.main_app.root_path` | Destination when the host reports that an account profile is incomplete. |
| `profile_complete` | `(account)` | `true` | Predicate used by `require_verified_account` after authentication and email verification. |
| `after_account_created` | `(account, controller)` | no-op | Notification hook after registration creates an account. Its return value is ignored. |
| `after_account_bootstrapped` | `(account)` | no-op | Host hook after the initial bootstrap account is created and before its invitation is delivered. Use it for host-owned role or assignment setup. |
| `account_password_reset_url` | `(mailer, plain_token)` | `mailer.edit_account_password_reset_url(token:)` | Absolute or host-generated password-reset URL included in mail. |
| `account_invitation_url` | `(mailer, plain_token)` | `mailer.account_invitation_url(token:)` | Absolute or host-generated invitation activation URL included in mail. |

Hooks running in a mounted Engine usually need `controller.main_app` to call
host route helpers. Mailer URL generation also requires the host application's
`default_url_options` to contain the correct production host and protocol.
Both URL callables receive a plaintext bearer token only while rendering the
message. Do not log their arguments or return values.

`after_account_bootstrapped` runs inside the bootstrap account transaction. If
the hook raises, AnnesAuth rolls back the account and bootstrap claim and does
not send an invitation. Keep role, permission, or organization writes in the
host app or `annes_access`; AnnesAuth does not reference those constants.

## Account Event Notifications

AnnesAuth instruments authentication lifecycle events through
`ActiveSupport::Notifications`:

```ruby
ActiveSupport::Notifications.subscribe("annes_auth.account_event") do |event|
  payload = event.payload.symbolize_keys
  # Enqueue a host job, persist an audit record, or delegate to an audit engine.
end
```

Events currently include:

- `sign_in`
- `sign_out`
- `password_reset_requested`
- `password_reset_completed`
- `email_verified`
- `invitation_sent`
- `invitation_accepted`

Payload keys are stable: `event`, `account_id`, `account_class`,
`account_email`, `session_id`, `auth_method`, `provider`, `ip_address`,
`user_agent`, `status`, and `metadata`. The payload intentionally excludes
passwords, reset tokens, invitation tokens, verification codes, session cookies,
and OAuth credentials. Treat `account_email`, IP address, and user agent as PII
when deciding what the subscriber stores.

## Google OAuth

| Setting | Default | Notes |
| --- | --- | --- |
| `google_oauth_enabled` | `false` | Feature switch. Credentials must also be present. |
| `google_oauth_client_id` | `nil` | OAuth client ID; normally loaded from the environment. |
| `google_oauth_client_secret` | `nil` | OAuth client secret; never commit it to source control. |

AnnesAuth processes a callback only when all three values indicate that Google
OAuth is configured:

```ruby
config.google_oauth_client_id = ENV["GOOGLE_OAUTH_CLIENT_ID"].presence
config.google_oauth_client_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"].presence
config.google_oauth_enabled =
  config.google_oauth_client_id.present? && config.google_oauth_client_secret.present?
```

Middleware setup and request validation are covered in
[Security and operations](security-and-operations.md).

## Model and Table Mapping

The defaults use Engine-owned models and host-installed tables.

| Setting | Default |
| --- | --- |
| `account_class_name` | `"AnnesAuth::Account"` |
| `account_session_class_name` | `"AnnesAuth::AccountSession"` |
| `account_identity_class_name` | `"AnnesAuth::AccountIdentity"` |
| `account_verification_token_class_name` | `"AnnesAuth::AccountVerificationToken"` |
| `account_password_reset_token_class_name` | `"AnnesAuth::AccountPasswordResetToken"` |
| `account_invitation_token_class_name` | `"AnnesAuth::AccountInvitationToken"` |
| `account_table_name` | `"accounts"` |
| `account_session_table_name` | `"account_sessions"` |
| `account_identity_table_name` | `"account_identities"` |
| `account_verification_token_table_name` | `"account_verification_tokens"` |
| `account_password_reset_token_table_name` | `"account_password_reset_tokens"` |
| `account_invitation_token_table_name` | `"account_invitation_tokens"` |
| `bootstrap_claim_table_name` | `"annes_auth_bootstrap_claims"` |
| `account_foreign_key` | `:account_id` |

These values form one mapping contract. Changing one model, table, or foreign
key can require changing the related settings, host migrations, associations,
fixtures, and indexes. Configure them before Rails eager-loads the AnnesAuth
models because table names and association class names are read by model class
definitions.

A common host wrapper keeps the default tables while adding host behavior:

```ruby
class Account < AnnesAuth::Account
  include AccountProfile
end

AnnesAuth.configure do |config|
  config.account_class_name = "Account"
end
```

Keep domain associations and business rules in the host subclass or concerns;
do not add host constants to the Engine. Test registration, every token flow,
session loading, and dependent deletion after changing model mappings.

For example, a host that uses `CustomerAccount` and a custom invitation-token
table must configure the account class, invitation class, table, and foreign key
as one unit:

```ruby
AnnesAuth.configure do |config|
  config.account_class_name = "CustomerAccount"
  config.account_table_name = "customer_accounts"
  config.account_invitation_token_class_name = "CustomerAccountInvitationToken"
  config.account_invitation_token_table_name = "customer_account_invitation_tokens"
  config.account_foreign_key = :customer_account_id
end
```

`CustomerAccountInvitationToken` should inherit
`AnnesAuth::AccountInvitationToken`. Its host migration must create
`customer_account_invitation_tokens.customer_account_id` and the matching
foreign key/index. Apply these settings during boot, before either model is
eager-loaded.

## Verification Token Digest

`account_verification_digest_salt` defaults to
`"annes_auth/account_verification_code"`. It is passed to the Rails application
key generator before verification codes are HMAC-digested. Changing it makes
outstanding verification codes unreadable, so rotate it only with an explicit
invalidation plan.

## Resetting Configuration in Tests

`AnnesAuth.reset_configuration!` restores all defaults. Use it around tests that
mutate global configuration so settings do not leak between examples.
