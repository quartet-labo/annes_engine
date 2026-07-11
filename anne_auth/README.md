# AnneAuth

AnneAuth is a Rails Engine for reusable account authentication. It provides
account models, registration, session handling, default authentication views,
email verification, password resets, Google OAuth support, controller concerns,
and host hooks.

This engine is developed in the `quartet-labo/anne_engine` monorepo under
`anne_auth`.

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

## Quick Start

Add the engine to the host app:

```ruby
source "https://rubygems.org"

source "https://rubygems.pkg.github.com/quartet-labo" do
  gem "anne_auth", "~> 0.3.0"
end
```

Configure Bundler credentials before installing. Use a token with
`read:packages` access.

```sh
bundle config https://rubygems.pkg.github.com/quartet-labo GITHUB_USERNAME:GITHUB_PACKAGES_TOKEN
```

For local development from a host application, use a path source:

```ruby
gem "anne_auth", path: "../anne_engine/anne_auth"
```

Run the installer:

```sh
bin/rails generate anne_auth:install
bin/rails db:migrate
```

The generator copies:

- `config/initializers/anne_auth.rb`
- `config/routes/anne_auth.rb`
- authentication migrations under `db/migrate`

Review the generated route example, then mount the Engine in
`config/routes.rb`:

```ruby
mount AnneAuth::Engine => "/"
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
- `GET /email_verification/pending`
- `GET /logout/confirm`

Migration files are installed with fresh timestamps in the host application. If a
host application already has an AnneAuth migration with the same name, the
installer skips that migration instead of creating a duplicate. Review skipped
migrations before running `bin/rails db:migrate`, especially when upgrading from
an in-repository path gem.

New installs use `accounts` and `account_sessions`. AnneAuth does not generate
or manage an admin-specific authentication principal. Keep admin access
decisions in `anne_admin` or host authorization code.

Review the generated initializer before starting the host application. At a
minimum, set a real sender address and application-specific redirect paths:

```ruby
AnneAuth.configure do |config|
  config.mailer_from = "noreply@example.com"
  config.after_account_login_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_email_verification_path = ->(controller, _account) { controller.main_app.root_path }
end
```

## Host Hooks

Use `AnneAuth.configure` to keep application-specific behavior outside the
Engine:

```ruby
AnneAuth.configure do |config|
  config.mailer_from = "noreply@example.com"
  config.account_mailer_class_name = "AnneAuth::AccountMailer"
  config.google_oauth_client_id = ENV["GOOGLE_OAUTH_CLIENT_ID"].presence
  config.google_oauth_client_secret = ENV["GOOGLE_OAUTH_CLIENT_SECRET"].presence
  config.google_oauth_enabled = config.google_oauth_client_id.present? && config.google_oauth_client_secret.present?

  config.after_account_login_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_email_verification_path = ->(controller, _account) { controller.main_app.root_path }
  config.after_account_profile_completion_path = ->(controller, _account) { controller.main_app.root_path }
  config.account_profile_path = ->(controller, _account) { controller.main_app.root_path }
  config.profile_complete = ->(_account) { true }
  config.after_account_created = ->(_account, _controller) {}
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

Account sessions use `AnneAuth::AccountSession` by default and store records in
the `account_sessions` table with an `account_id` foreign key:

```ruby
AnneAuth.configure do |config|
  config.account_class_name = "AnneAuth::Account"
  config.account_session_class_name = "AnneAuth::AccountSession"
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

Controllers can include `AnneAuth::AccountAuthentication` and use
`current_account`, `account_authenticated?`, `require_account_authentication`,
`start_new_account_session_for(account)`, and `terminate_account_session`.

Login, signup, password reset, and email verification resend actions use Rails
controller rate limits. Production host apps should configure a shared
`ActiveSupport::Cache` store, such as Redis or Solid Cache, when running more
than one process or server so the limits are enforced consistently.

AnneAuth should authenticate an account; it should not decide whether that
account is an administrator. Host apps that previously created `admin_users` or
`sessions.admin_user_id` should keep any cleanup migration in the host app after
confirming those tables are no longer used.

The host app should keep domain models such as customers, projects, orders, or
quotes outside this Engine and connect them through hooks or thin host
controllers.

## Package Boundary

AnneAuth owns generic authentication primitives only. Runtime code must not reference host application domain constants such as `Customer`, `Project`, or `QuoteRequest`.

Host applications can provide compatibility wrappers when they need legacy class or helper names:

```ruby
class CustomerAccount < AnneAuth::Account
  include CustomerAccountProfile
end
```

Keep those wrappers in the host application. Do not add application-specific associations, routes, or services to the engine.

## Release Workflow

The distribution target is GitHub Packages. Use this flow for releases:

1. Run the engine test suite from the engine repository with `bundle exec rake test`.
2. Update `lib/anne_auth/version.rb` to the version you want to publish.
3. Update `CHANGELOG.md` for that version.
4. Commit the release.
5. Push a gem-specific tag such as `anne_auth-vX.Y.Z`, matching `AnneAuth::VERSION`.
6. Confirm the `Publish Gems` workflow published the package to GitHub Packages
   and created the GitHub Release for the tag.
7. Update host applications with `bundle update anne_auth` and run their full test suites.

The workflow fails if the tag version does not match `AnneAuth::VERSION`. You
can also run the `Publish Gems` workflow manually and choose `anne_auth`; manual
runs publish the version currently defined by the gemspec without creating a
GitHub Release.

## Google OAuth

Set these environment variables when Google login is enabled:

- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`

The callback path is `/auth/google_oauth2/callback` when the Engine is mounted
at `/`.

Configure OmniAuth in the host application and keep request validation enabled:

```ruby
OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.request_validation_phase = AnneAuth::OmniauthTokenVerifier.new

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    ENV.fetch("GOOGLE_OAUTH_CLIENT_ID"),
    ENV.fetch("GOOGLE_OAUTH_CLIENT_SECRET")
end
```

AnneAuth only processes the Google callback when
`config.google_oauth_enabled`, `config.google_oauth_client_id`, and
`config.google_oauth_client_secret` are all present. If Google login is disabled
in AnneAuth, the callback redirects back to login without creating or signing in
an account.
