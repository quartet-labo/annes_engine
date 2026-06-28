# AnneAuth

AnneAuth is a Rails Engine for reusable account authentication. It provides account models, session handling, email verification, password resets, Google OAuth support, controller concerns, and host hooks.

This engine is developed in the `quartet-labo/anne_engine` monorepo under
`anne_auth`.

```ruby
git "git@github.com:quartet-labo/anne_engine.git", tag: "v0.1.0" do
  gem "anne_auth"
end
```

Run the engine-focused test suite from this directory:

```sh
bundle exec rake test
```

## Installation

Add the engine to the host app:

```ruby
git "git@github.com:quartet-labo/anne_engine.git", tag: "v0.1.0" do
  gem "anne_auth"
end
```

Keep the host app on a released tag and use Bundler's local override when
developing the engine and host together:

```sh
bundle config set local.anne_auth ../anne_engine
```

Release tags must match `AnneAuth::VERSION` with a `v` prefix, for example `v0.1.0`.

Run the installer:

```sh
bin/rails generate anne_auth:install
```

The generator copies:

- `config/initializers/anne_auth.rb`
- `config/routes/anne_auth.rb`
- authentication migrations under `db/migrate`

Review the route example and either mount the Engine or keep thin host
controllers that inherit the Engine controllers when existing path helper names
must be preserved.

Migration files are installed with fresh timestamps in the host application. If a
host application already has an AnneAuth migration with the same name, the
installer skips that migration instead of creating a duplicate. Review skipped
migrations before running `bin/rails db:migrate`, especially when upgrading from
an in-repository path gem.

## Host Hooks

Use `AnneAuth.configure` to keep application-specific behavior outside the
Engine:

```ruby
AnneAuth.configure do |config|
  config.after_account_login_path = ->(controller, _account) { controller.root_path }
  config.account_profile_path = ->(controller, _account) { controller.root_path }
  config.profile_complete = ->(account) { true }
  config.after_account_created = ->(account, controller) {}
end
```

Admin sessions use `AnneAuth::AdminSession` by default and store records in the
`sessions` table. Existing host applications that already have a custom
`Session < AnneAuth::AdminSession` wrapper can keep it by opting in explicitly:

```ruby
AnneAuth.configure do |config|
  config.admin_session_class_name = "Session"
end
```

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

The initial distribution target is a private git gem. Use this flow for releases:

1. Run the engine test suite from the engine repository with `bundle exec rake test`.
2. Update `CHANGELOG.md` and `lib/anne_auth/version.rb` when behavior changes.
3. Commit the release and tag it as `vX.Y.Z`.
4. Update host applications to the new tag and run their full test suites.

## Google OAuth

Set these environment variables when Google login is enabled:

- `GOOGLE_OAUTH_CLIENT_ID`
- `GOOGLE_OAUTH_CLIENT_SECRET`

The callback path is `/auth/google_oauth2/callback` when the Engine is mounted
at `/`.
