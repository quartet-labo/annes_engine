# AnnesAuth

AnnesAuth is a Rails Engine for reusable account authentication. It provides
account models, registration, session handling, default authentication views,
email verification, password resets, account invitation activation, Google OAuth
support, initial account bootstrap, account event hooks, controller concerns,
and host hooks.

This engine is developed in the `quartet-labo/annes_engine` monorepo under
`annes_auth`.

## Requirements

- Ruby 3.4 or newer
- Rails 8.1

## Documentation

- [Configuration reference](docs/configuration.md)
- [Routes and host integration](docs/routes-and-host-integration.md)
- [Security and operations](docs/security-and-operations.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Upgrade guide](UPGRADING.md)

Run the engine-focused test suite from this directory:

```sh
bundle exec rake test
```

## Default Login Form Submit Guard

The default email/password login form opts into AnnesAuth's dependency-free
submit guard. After the browser accepts the first submit event, the form is
marked `aria-busy="true"` and its submit controls are disabled. Repeated
submits are blocked until browser history restoration or a Turbo submission
completion resets the state. Native constraint validation still runs before the
guard, and the submitter's `name=value` remains in the request.

Applications that override the login view must preserve
`data-annes-auth-submit-guard` on the credential form. Applications that
override the AnnesAuth layout must render
`layouts/annes_auth/submit_guard`; the partial supplies its inline script with
the current Content Security Policy nonce. No Turbo, Stimulus, importmap,
rails-ujs, or npm runtime dependency is required.

## Quick Start

Add the engine to the host app:

```ruby
source "https://rubygems.org"

source "https://rubygems.pkg.github.com/quartet-labo" do
  gem "annes_auth", "~> 1.0"
end
```

Configure Bundler credentials before installing. Use a token with
`read:packages` access.

```sh
bundle config https://rubygems.pkg.github.com/quartet-labo GITHUB_USERNAME:GITHUB_PACKAGES_TOKEN
```

For local development from a host application, use a path source:

```ruby
gem "annes_auth", path: "../annes_engine/annes_auth"
```

Run the installer:

```sh
bin/rails generate annes_auth:install
bin/rails db:migrate
```

The generator copies:

- `config/initializers/annes_auth.rb`
- `config/routes/annes_auth.rb`
- authentication migrations under `db/migrate`

Review the generated route example, then mount the Engine in
`config/routes.rb`:

```ruby
mount AnnesAuth::Engine => "/"
```

Mounting at `/` provides the default authentication screens and route helpers.
For a different prefix, mount at a path such as `/auth`. Keep thin host
controllers that inherit the Engine controllers when existing path helper names
must be preserved. See [Routes and host integration](docs/routes-and-host-integration.md).

When mounted at `/`, the Engine includes these default account routes and views:

- `GET /login`
- `POST /account_session`
- `GET /signup`
- `POST /account_registration`
- `GET /password_reset/new`
- `GET /password_reset/edit`
- `GET /invitation?token=...`
- `GET /invitation/edit`
- `PATCH /invitation`
- `GET /email_verification/pending`
- `GET /logout/confirm`

Migration files are installed with fresh timestamps in the host application. If a
host application already has an AnnesAuth migration with the same name, the
installer skips that migration instead of creating a duplicate. Review skipped
migrations before running `bin/rails db:migrate`, especially when upgrading from
an in-repository path gem.

New installs use `accounts` and `account_sessions`. AnnesAuth does not generate
or manage an admin-specific authentication principal. Keep admin access
decisions in `annes_admin` or host authorization code.

Review the generated initializer before starting the host application. At a
minimum, set a real sender address and application-specific redirect paths:

```ruby
AnnesAuth.configure do |config|
  config.mailer_from = "noreply@example.com"
  config.after_account_login_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_email_verification_path = ->(controller, _account) { controller.main_app.root_path }
  config.account_invitation_url = ->(mailer, token) { mailer.account_invitation_url(token:) }
  config.after_account_bootstrapped = ->(_account) {}
end
```

## Host Hooks

Use `AnnesAuth.configure` to keep application-specific behavior outside the
Engine:

```ruby
AnnesAuth.configure do |config|
  config.mailer_from = "noreply@example.com"
  config.account_mailer_class_name = "AnnesAuth::AccountMailer"
  config.google_oauth_client_id = ENV["GOOGLE_OAUTH_CLIENT_ID"].presence
  config.google_oauth_client_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"].presence
  config.google_oauth_enabled = config.google_oauth_client_id.present? && config.google_oauth_client_secret.present?

  config.after_account_login_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_email_verification_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_profile_completion_path = ->(controller, _account) { controller.main_app.root_path }
  config.account_profile_path = ->(controller, _account) { controller.main_app.root_path }
  config.account_invitation_url = ->(mailer, token) { mailer.account_invitation_url(token:) }
  config.profile_complete = ->(_account) { true }
  config.after_account_created = ->(_account, _controller) {}
  config.after_account_bootstrapped = ->(_account) {}
end
```

`after_account_email_verification_path` controls where an account goes after a
successful email code verification. Mounted Engine installs can point this to a
host route such as `controller.main_app.root_path` or a dashboard path without
overriding Engine controllers.

`after_account_login_path` is also used when an already authenticated, verified
account visits account entry pages such as login, signup, or email verification
pending. Unverified accounts are sent back to the email verification pending
page.

Successful password login creates an account session, but unverified accounts
are redirected to the email verification pending page instead of
`after_account_login_path`. Host screens that require verified accounts should
use `require_verified_account`; use `require_account_authentication` only for
screens that intentionally allow unverified accounts.

Account sessions use `AnnesAuth::AccountSession` by default and store records in
the `account_sessions` table with an `account_id` foreign key:

```ruby
AnnesAuth.configure do |config|
  config.account_class_name = "AnnesAuth::Account"
  config.account_session_class_name = "AnnesAuth::AccountSession"
  config.account_foreign_key = :account_id
  config.account_session_cookie_name = :account_session_id
  config.account_password_minimum_length = 12
  config.account_session_expires_in = 2.weeks
  config.account_session_cookie_secure = ->(request) { request.ssl? || Rails.env.production? }
end
```

`account_password_minimum_length` is enforced when accounts are created and when
passwords are reset.

`account_session_expires_in` controls both the database session expiry and the
signed login cookie expiry. Expired sessions are rejected and removed on the
next request.

Controllers can include `AnnesAuth::AccountAuthentication` and use
`current_account`, `account_authenticated?`, `require_account_authentication`,
`start_new_account_session_for(account)`, and `terminate_account_session`.

Login, signup, password reset, and email verification resend actions use Rails
controller rate limits. Production host apps should configure a shared
`ActiveSupport::Cache` store, such as Redis or Solid Cache, when running more
than one process or server so the limits are enforced consistently.

AnnesAuth should authenticate an account; it should not decide whether that
account is an administrator. Host apps that previously created `admin_users` or
`sessions.admin_user_id` should keep any cleanup migration in the host app after
confirming those tables are no longer used.

The host app should keep domain models such as customers, projects, orders, or
quotes outside this Engine and connect them through hooks or thin host
controllers.

## Initial Account Bootstrap

Version 0.4.0 adds a trusted bootstrap service for the first account in a new
host application. It creates one unverified account with a random temporary
password and sends the existing invitation activation email so the person sets
their real password through `/invitation`.

Run the installer and migrate before using it:

```sh
bin/rails generate annes_auth:install
bin/rails db:migrate
```

Call the service from trusted setup code, such as a one-off console command,
deployment job, or seed task. Do not expose it as a public controller action.

```ruby
result = AnnesAuth::Accounts::BootstrapInvitation.call(
  email: "owner@example.com"
)

case result.status
when :delivered
  # Initial account created and invitation sent.
when :already_bootstrapped
  # An active account or completed bootstrap already exists.
when :invalid_account
  # Email or host account validation failed.
when :delivery_failed
  # Retry the same call after fixing mail delivery.
end
```

Use `after_account_bootstrapped` for host-owned role or assignment setup. The
hook runs before invitation delivery; if it raises, the account and bootstrap
claim roll back and no invitation is sent.

```ruby
AnnesAuth.configure do |config|
  config.after_account_bootstrapped = ->(account) {
    # Example: assign an AnnesAccess role in the host app.
  }
end
```

AnnesAuth does not decide whether the account is an administrator. Keep role
creation, permission assignment, and organization membership in the host app,
`annes_access`, or another engine.

## Account Invitations

Version 0.3.2 adds a server-side invitation API and an activation flow for
accounts created by trusted host jobs or management operations. Install the
invitation-token migration before sending an invitation:

```sh
bin/rails generate annes_auth:install
bin/rails db:migrate
```

These commands assume the default `accounts` table and `account_id` foreign
key. If the host uses custom account mappings, do not run the generated
invitation migration unchanged. Adapt it before migrating by following the two
paths in the [upgrade guide](UPGRADING.md).

Call the service directly from trusted application code. AnnesAuth intentionally
does not expose an HTTP endpoint that issues invitations.

```ruby
result = AnnesAuth::Accounts::InvitationDelivery.call(account)

case result.status
when :delivered
  # The invitation email was delivered synchronously.
when :invalid_account
  # The account is not persisted, is disabled, or is already verified.
when :delivery_failed
  # Retry from the host job according to its delivery policy.
end
```

The Result contains only the status; it never returns the plaintext bearer
token. Resending issues a new one-hour invitation and invalidates the previous
link. Configure the absolute activation URL and production mailer host:

```ruby
# config/initializers/annes_auth.rb
config.account_invitation_url = ->(mailer, token) {
  mailer.account_invitation_url(token: token)
}

# config/environments/production.rb
config.action_mailer.default_url_options = {
  host: "app.example.com",
  protocol: "https"
}
```

The emailed link enters at `GET /invitation?token=...`. That request validates
but does not consume the invitation, stores only the invitation record ID in the
encrypted Rails session, and redirects to token-free `GET /invitation/edit`.
`PATCH /invitation` sets the password and verifies the email address. Success
invalidates the account's invitation, password-reset, verification, and session
credentials, then sends the person to login without creating a new session.

Host applications that map AnnesAuth to custom account and token models must set
the invitation class, table, and shared foreign key before the models load:

```ruby
AnnesAuth.configure do |config|
  config.account_class_name = "CustomerAccount"
  config.account_table_name = "customer_accounts"
  config.account_invitation_token_class_name = "CustomerAccountInvitationToken"
  config.account_invitation_token_table_name = "customer_account_invitation_tokens"
  config.account_foreign_key = :customer_account_id
end
```

The host migration and associations must use the same table and foreign key.
Do not run the generator's default invitation migration unchanged for this
mapping. See the [upgrade guide](UPGRADING.md) for a custom migration example,
the [configuration reference](docs/configuration.md) for the full mapping
contract, and [Security and operations](docs/security-and-operations.md) for
bearer-token logging controls.

## Account Events

Version 0.4.0 instruments authentication lifecycle events with
`ActiveSupport::Notifications`:

```ruby
ActiveSupport::Notifications.subscribe("annes_auth.account_event") do |event|
  AuthEventJob.perform_later(
    event_id: event.transaction_id,
    occurred_at: Time.zone.at(event.time),
    **event.payload.symbolize_keys
  )
end
```

Current event names are `sign_in`, `sign_out`, `password_reset_requested`,
`password_reset_completed`, `email_verified`, `invitation_sent`, and
`invitation_accepted`. Payloads include account id/class/email, database
session id when available, auth method, provider, request IP/user agent, status,
and non-secret metadata. They do not include passwords, reset tokens,
invitation tokens, verification codes, session cookies, or OAuth credentials.

Use subscribers to enqueue jobs, persist audit entries, or delegate to a future
audit engine. Keep subscribers fast and decide in the host app whether a
subscriber failure should fail the authentication request.

## Package Boundary

AnnesAuth owns generic authentication primitives only. Runtime code must not reference host application domain constants such as `Customer`, `Project`, or `QuoteRequest`.

Host applications can provide compatibility wrappers when they need legacy class or helper names:

```ruby
class CustomerAccount < AnnesAuth::Account
  include CustomerAccountProfile
end
```

Keep those wrappers in the host application. Do not add application-specific associations, routes, or services to the engine.

## Release Workflow

The distribution target is GitHub Packages. Use this flow for releases:

1. Run the engine test suite from the engine repository with `bundle exec rake test`.
2. Update `lib/annes_auth/version.rb` to the version you want to publish.
3. Update `CHANGELOG.md` and `UPGRADING.md` for that version.
4. Update the dependent example app lockfiles by running `bundle update annes_auth`
   from `examples/customer_management`, `examples/resavation_management`, and
   `examples/restaurant_loyalty`.
5. Commit the release, including the changed example `Gemfile.lock` files.
6. Run the `Publish Gems` workflow with the `workflow_dispatch` trigger,
   selecting the `main` ref, `gem` = `annes_auth`, and `version` equal to
   `AnnesAuth::VERSION`.
7. Confirm the workflow published the package to GitHub Packages. The same
   workflow creates the gem-specific tag and GitHub Release for that version.
8. Update host applications with `bundle update annes_auth` and run their full test suites.

The workflow fails before publishing if the `version` input does not match
`AnnesAuth::VERSION`, the changelog section is missing or empty, or the remote
gem-specific tag already exists. Tag push events are not the release entrypoint.

## Google OAuth

Set these environment variables when Google login is enabled:

- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`

The callback path is `/auth/google_oauth2/callback` when the Engine is mounted
at `/`.

Configure OmniAuth in the host application and keep request validation enabled:

```ruby
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.request_validation_phase = AnnesAuth::OmniauthTokenVerifier.new

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV.fetch("GOOGLE_OAUTH_CLIENT_ID"),
    ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET")
end
```

AnnesAuth only processes the Google callback when
`config.google_oauth_enabled`, `config.google_oauth_client_id`, and
`config.google_oauth_client_secret` are all present. If Google login is disabled
in AnnesAuth, the callback redirects back to login without creating or signing in
an account.

## License and Support

AnnesAuth is available under the
[MIT License](https://github.com/quartet-labo/annes_engine/blob/main/MIT-LICENSE).
Open-source use does not include support, maintenance, fixes, compatibility
guarantees, or release commitments. See the shared
[support policy](https://github.com/quartet-labo/annes_engine/blob/main/SUPPORT.md)
for community-use boundaries and separately available paid services.
